# PostgreSQL Cloudflare R2 Backup

Um serviço em Docker projetado para realizar dumps de bancos PostgreSQL diariamente (03:00 - Recife) de forma automatizada e enviar o arquivo de forma segura para o Cloudflare R2 utilizando `rclone`. O backup é feito em formato custom (`-Fc`).

## Funcionalidades
- **Automação Diária:** Cron configurado para as 03:00 AM (fuso América/Recife).
- **Sem senhas expostas:** Utiliza variáveis de ambiente.
- **Upload para R2 via rclone:** Extremamente rápido e seguro.
- **Isolamento de Erros:** O backup local não é sobrescrito se houver falha, as políticas de expiração só atuam após um novo backup ser validado.
- **Gerenciamento de Retenção Local:** Arquivos `.dump` antigos (> 7 dias) são removidos do disco.
- **Gerenciamento de Retenção Remota:** Arquivos antigos no R2 (> 30 dias) são removidos.
- **Healthcheck:** Para monitorar ativamente se o script falhou.

## Variáveis Necessárias (Configure no EasyPanel)
- `POSTGRES_HOST`: O Host (ex: nome do serviço no Docker) do PostgreSQL
- `POSTGRES_PORT`: Opcional (Padrão 5432)
- `POSTGRES_DB`: Nome do banco a ser feito o dump
- `POSTGRES_USER`: Usuário do banco
- `POSTGRES_PASSWORD`: Senha (não exposta via comando)
- `R2_BUCKET`: Nome do Bucket do Cloudflare R2
- `R2_ENDPOINT`: Ex: https://<ID>.r2.cloudflarestorage.com
- `R2_ACCESS_KEY`: Acesso gerado no dashboard do R2
- `R2_SECRET_KEY`: Senha de acesso

> Consulte o arquivo `.env.example` se precisar de uma base.

## Como fazer o Deploy

No EasyPanel, basta criar um novo serviço escolhendo **GitHub** (caso adicione o código num repositório) ou **Docker Compose**, forneça as variáveis de ambiente na interface do usuário, mapeie o volume `/backups/local` e clique em Deploy.
