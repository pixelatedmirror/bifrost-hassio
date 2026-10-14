#!/usr/bin/env bash
set -e

CONFIG_DIR="/config/bifrost"
mkdir -p "$CONFIG_DIR"

if [ -f "/data/options.json" ]; then
    USER_CONFIG=$(jq -r '.config // empty' /data/options.json)
    if [ -n "$USER_CONFIG" ] && [ "$USER_CONFIG" != "null" ]; then
        echo "$USER_CONFIG" > "$CONFIG_DIR/config.yaml"
    fi
fi

cd "$CONFIG_DIR"
exec /app/bifrost "$@"
