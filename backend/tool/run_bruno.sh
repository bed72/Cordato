#!/bin/sh
set -eu

if [ "$#" -ne 1 ] || [ "$1" != authentication/01-login.bru ]; then
    printf '%s\n' 'Use authentication/01-login.bru ou make bruno-upload.' >&2
    exit 1
fi

cd bruno
exec bru run "$1" --env example --sandbox safe --bail --noproxy \
    --reporter-skip-all-headers --reporter-skip-body
