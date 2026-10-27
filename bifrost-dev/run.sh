#!/usr/bin/env bash
set -e

CONFIG_DIR="/config/bifrost"
mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_DIR/config.yaml" ]; then
    # Always preserve a backup of the existing config
    cp -p "$CONFIG_DIR/config.yaml" "$CONFIG_DIR/config.yaml.bak"
fi

if [ -f "/data/options.json" ]; then
    LOG_LEVEL=$(jq -r '.log_level // empty' /data/options.json)
    if [ -n "$LOG_LEVEL" ] && [ "$LOG_LEVEL" != "null" ]; then
        case "$LOG_LEVEL" in
            warning) RUST_LEVEL="warn" ;;
            notice)  RUST_LEVEL="info" ;;
            fatal)   RUST_LEVEL="error" ;;
            *)       RUST_LEVEL="$LOG_LEVEL" ;;
        esac
        export RUST_LOG="$RUST_LEVEL,mdns_sd=off,tokio_ssdp=info,tower_http::trace::on_request=info,h2=info,axum::rejection=trace"
        echo "[run.sh] Setting log level to $RUST_LEVEL"
    fi

    USER_CONFIG=$(jq -r '.config // empty' /data/options.json)
    if [ -n "$USER_CONFIG" ] && [ "$USER_CONFIG" != "null" ]; then
        echo "$USER_CONFIG" > "$CONFIG_DIR/config.yaml"
    else
        HAS_BRIDGE=$(jq -r '.bridge // empty' /data/options.json)
        IP=$(jq -r '.bridge.ipaddress // empty' /data/options.json)
        if [ -n "$HAS_BRIDGE" ]; then
            if [ -f "$CONFIG_DIR/config.yaml" ] && [ "$IP" = "10.12.0.20" ]; then
                echo "[run.sh] Preserving existing config.yaml (options contain placeholder IP 10.12.0.20)."
            else
                echo "[run.sh] Generating config.yaml from add-on options..."
                jq -r '
                {
                  bifrost: (.bifrost // {}),
                  bridge: (.bridge // {}),
                  z2m: (
                    if .z2m_servers then
                      reduce .z2m_servers[] as $s ({}; .[$s.name] = ($s | del(.name)))
                    elif .z2m then
                      .z2m
                    else
                      {}
                    end
                  )
                } |
                def to_yaml(indent):
                  to_entries[] |
                  if (.value | type) == "object" then
                    "\(indent)\(.key):", (.value | to_yaml(indent + "  "))
                  elif .value != null and .value != "" then
                    "\(indent)\(.key): \(.value)"
                  else
                    empty
                  end;
                to_yaml("")
                ' /data/options.json > "$CONFIG_DIR/config.yaml"
            fi
        fi
    fi
fi

cd "$CONFIG_DIR"
exec /app/bifrost "$@"
