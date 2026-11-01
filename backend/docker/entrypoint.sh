#!/bin/sh
set -eu

# Conte bytes, não caracteres Unicode: a chave AES precisa ter 32 bytes.
export LC_ALL=C
export POCKETBASE_ENCRYPTION_KEY="${POCKETBASE_ENCRYPTION_KEY:-}"
if [ "${#POCKETBASE_ENCRYPTION_KEY}" -ne 32 ]; then
    printf 'POCKETBASE_ENCRYPTION_KEY deve conter exatamente 32 bytes (use ASCII).\n' >&2
    exit 1
fi

# Sem opções externas que possam desabilitar criptografia ou habilitar hooks/debug.
exec pocketbase serve \
    --http=0.0.0.0:8090 \
    --dir=/pb/pb_data \
    --migrationsDir=/opt/cordato/migrations \
    --hooksDir=/opt/cordato/no-hooks \
    --publicDir=/opt/cordato/no-public \
    --automigrate=false \
    --encryptionEnv=POCKETBASE_ENCRYPTION_KEY
