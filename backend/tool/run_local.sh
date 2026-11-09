#!/bin/sh
set -eu

export LC_ALL=C
export POCKETBASE_ENCRYPTION_KEY="${POCKETBASE_ENCRYPTION_KEY:-}"
if [ "${#POCKETBASE_ENCRYPTION_KEY}" -ne 32 ]; then
    printf '%s\n' 'POCKETBASE_ENCRYPTION_KEY deve conter exatamente 32 bytes.' >&2
    exit 1
fi

exec go run ./cmd/cordato serve \
    --http=127.0.0.1:8091 \
    --dir=.temp/cordato/pb_data \
    --migrationsDir=pb_migrations \
    --automigrate=false
