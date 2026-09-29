#!/bin/bash
# Ativar tratamento rígido de erros: 
# -e: sai no primeiro erro; -u: erro se variável não definida; -o pipefail: erro em qualquer parte do pipe
set -euo pipefail

# Função para logs com timestamp
log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

# Variáveis (PGPASSWORD é lida nativamente pelo pg_dump sem precisar passá-la na linha de comando)
DB_HOST="${POSTGRES_HOST}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB}"
DB_USER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"

BACKUP_DIR="/backups/local"
R2_PATH="postgres"

mkdir -p "${BACKUP_DIR}"

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
BACKUP_FILENAME="${DB_NAME}_${TIMESTAMP}.dump"
LOCAL_BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILENAME}"

log "========================================"
log "INICIANDO PROCESSO DE BACKUP: ${DB_NAME}"

# 1. Executar pg_dump
log "1/5 - Executando pg_dump..."
if pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -Fc -f "${LOCAL_BACKUP_PATH}"; then
    log "pg_dump local concluído com sucesso."
else
    log "ERRO CRÍTICO: Falha ao executar o pg_dump!"
    exit 1
fi

# 2. Verificar validade do arquivo
if [ ! -s "${LOCAL_BACKUP_PATH}" ]; then
    log "ERRO CRÍTICO: Arquivo de backup não foi criado ou está vazio: ${LOCAL_BACKUP_PATH}"
    rm -f "${LOCAL_BACKUP_PATH}"
    exit 1
fi

FILE_SIZE=$(du -h "${LOCAL_BACKUP_PATH}" | cut -f1)
log "2/5 - Arquivo verificado. Tamanho: ${FILE_SIZE}"

# 3. Configurar rclone dinamicamente via variáveis de ambiente
# O prefixo RCLONE_CONFIG_<nome>_ mapeia para as configs do rclone, evitando arquivos no disco.
export RCLONE_CONFIG_R2_TYPE="s3"
export RCLONE_CONFIG_R2_PROVIDER="Cloudflare"
export RCLONE_CONFIG_R2_ACCESS_KEY_ID="${R2_ACCESS_KEY}"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="${R2_SECRET_KEY}"
export RCLONE_CONFIG_R2_ENDPOINT="${R2_ENDPOINT}"
export RCLONE_CONFIG_R2_ACL="private"

# 4. Upload para Cloudflare R2
log "3/5 - Iniciando upload para Cloudflare R2..."
REMOTE_DEST="r2:${R2_BUCKET}/${R2_PATH}"

# O rclone copy vai tentar copiar. Se a rede cair, ele falha e o script aborta (set -e).
rclone copy "${LOCAL_BACKUP_PATH}" "${REMOTE_DEST}" --progress=false
log "Upload para R2 concluído com sucesso."

# 5. Limpeza de retenção (Só roda se o código chegar até aqui, ou seja, sucesso total)
log "4/5 - Aplicando regras de retenção..."

# Remover locais mais antigos que 7 dias
find "${BACKUP_DIR}" -name "${DB_NAME}_*.dump" -type f -mtime +7 -delete
log "Backups locais antigos removidos (Retenção: 7 dias)."

# Remover no R2 mais antigos que 30 dias usando a flag --min-age do próprio rclone
rclone delete "${REMOTE_DEST}" --min-age 30d --include "${DB_NAME}_*.dump"
log "Backups remotos antigos removidos (Retenção: 30 dias)."

# Atualizar arquivo para o Docker Healthcheck
touch /var/lib/backup/last_success

log "5/5 - BACKUP FINALIZADO COM SUCESSO."
log "========================================"
