#!/bin/sh
set -eu

node -e 'require("/opt/cordato/settings.js")'

if [ ! -e /data/flows.json ]; then
    cp /opt/cordato/flows.json /data/flows.json
fi

exec node /usr/src/node-red/node_modules/node-red/red.js \
    --userDir /data \
    --settings /opt/cordato/settings.js
