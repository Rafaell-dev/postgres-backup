# Se o seu banco for PostgreSQL 14, 15, ou 16, a versão no Alpine latest funcionará perfeitamente.
FROM alpine:3.19

# Instalar dependências necessárias
RUN apk add --no-cache \
    postgresql-client \
    rclone \
    bash \
    tzdata \
    findutils \
    coreutils

# Definir o Timezone para a execução do cron
ENV TZ=America/Recife
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

# Copiar scripts e crontab
COPY backup.sh /app/backup.sh
COPY crontab /etc/crontabs/root

# Dar permissão de execução
RUN chmod +x /app/backup.sh

# Criar diretório para o Health Check
RUN mkdir -p /var/lib/backup && touch /var/lib/backup/last_success

# Healthcheck: verifica se o arquivo de last_success foi modificado nas últimas 26 horas
# Se falhar hoje, ele acusa falha, garantindo que você saiba se o cron parou
HEALTHCHECK --interval=5m --timeout=3s \
  CMD test $(expr $(date +%s) - $(stat -c %Y /var/lib/backup/last_success)) -lt 93600 || exit 1

# Iniciar o daemon do cron em foreground e jogar logs para stdout
CMD ["crond", "-f", "-l", "2"]
