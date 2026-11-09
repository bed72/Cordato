#!/bin/sh
set -eu

environment_file=$1
shift

if [ -n "$environment_file" ]; then
    if [ ! -f "$environment_file" ]; then
        printf '%s\n' 'Arquivo de ambiente privado não encontrado; consulte backend/bruno/README.md.' >&2
        exit 1
    fi
    case "$environment_file" in
        /*) ;;
        *) environment_file="$(pwd)/$environment_file" ;;
    esac
    set -a
    . "$environment_file"
    set +a
fi

exec "$@"
