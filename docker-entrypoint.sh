#!/bin/sh
set -e

APP_DIR="/opt/e-imzo-server"
CONFIG_DIR="${APP_DIR}/config"
KEYS_DIR="${APP_DIR}/keys"
BASE_CONFIG="${CONFIG_DIR}/config.properties"

# Check if command is an arbitrary command (e.g. sh, bash, env, etc.)
# If $1 is not empty and not "start" and does not start with "-", execute directly
if [ "$#" -gt 0 ] && [ "$1" != "start" ] && [ "${1#-}" = "$1" ]; then
    exec "$@"
fi

# Detect environment preset (prod vs test)
EIMZO_ENV="${EIMZO_ENV:-${VPN_ENV:-prod}}"
if [ "$EIMZO_ENV" = "test" ]; then
    DEFAULT_VPN_HOST="testvpn.e-imzo.uz"
    DEFAULT_VPN_PORT="2443"
else
    DEFAULT_VPN_HOST="vpn.e-imzo.uz"
    DEFAULT_VPN_PORT="3443"
fi

VPN_CONNECT_HOST="${VPN_CONNECT_HOST:-$DEFAULT_VPN_HOST}"
VPN_CONNECT_PORT="${VPN_CONNECT_PORT:-$DEFAULT_VPN_PORT}"
LISTEN_IP="${LISTEN_IP:-0.0.0.0}"
LISTEN_PORT="${LISTEN_PORT:-8080}"
CACHE_TYPE="${CACHE_TYPE:-local}"

# Auto-detect VPN key if not explicitly configured
if [ -z "$VPN_KEY_FILE_PATH" ] && [ -d "$KEYS_DIR" ]; then
    KEY_COUNT=$(find "$KEYS_DIR" -maxdepth 1 -type f -name "*.key" 2>/dev/null | wc -l)
    if [ "$KEY_COUNT" -eq 1 ]; then
        FOUND_KEY=$(find "$KEYS_DIR" -maxdepth 1 -type f -name "*.key" | head -n 1)
        VPN_KEY_FILE_PATH="keys/$(basename "$FOUND_KEY")"
        echo "[e-imzo entrypoint] Auto-detected single VPN key: ${VPN_KEY_FILE_PATH}"
    elif [ "$KEY_COUNT" -gt 1 ]; then
        echo "[e-imzo entrypoint] NOTICE: Multiple .key files found in ${KEYS_DIR}. Please specify VPN_KEY_FILE_PATH."
    fi
fi

# Determine vpn.tls.enabled
# If no VPN key is provided and none was detected, fallback to plaintext mode to prevent crash
if [ -n "$VPN_KEY_FILE_PATH" ]; then
    ACTUAL_VPN_TLS="${VPN_TLS_ENABLED:-yes}"
else
    if [ "${VPN_TLS_ENABLED}" = "yes" ]; then
        echo "[e-imzo entrypoint] WARNING: vpn.tls.enabled was requested but no VPN key file was found in ${KEYS_DIR}."
        echo "[e-imzo entrypoint] WARNING: Starting in fallback plaintext mode. Mount keys to enable TLS VPN."
        ACTUAL_VPN_TLS="no"
    else
        ACTUAL_VPN_TLS="${VPN_TLS_ENABLED:-no}"
    fi
fi

# Auto-detect truststore files if present in keys directory
if [ -z "$VPN_TRUSTSTORE_FILE_PATH" ] && [ -f "${KEYS_DIR}/vpn.jks" ]; then
    VPN_TRUSTSTORE_FILE_PATH="keys/vpn.jks"
fi
if [ -z "$TSP_JKS_FILE_PATH" ] && [ -f "${KEYS_DIR}/truststore.jks" ]; then
    TSP_JKS_FILE_PATH="keys/truststore.jks"
fi

# Check whether config directory is writable
TARGET_CONFIG="${BASE_CONFIG}"
if [ ! -w "$(dirname "$TARGET_CONFIG")" ] && [ ! -w "$TARGET_CONFIG" ]; then
    TARGET_CONFIG="/tmp/config.properties"
    [ -f "$BASE_CONFIG" ] && cp "$BASE_CONFIG" "$TARGET_CONFIG"
elif [ ! -f "$TARGET_CONFIG" ]; then
    touch "$TARGET_CONFIG"
fi

# Function to set or replace key=value in config file
set_property() {
    _key="$1"
    _val="$2"
    if [ -n "$_val" ]; then
        sed -i "/^[[:space:]]*${_key}[[:space:]]*=/d" "$TARGET_CONFIG" 2>/dev/null || true
        echo "${_key}=${_val}" >> "$TARGET_CONFIG"
    fi
}

# Apply primary properties
set_property "listen.ip" "$LISTEN_IP"
set_property "listen.port" "$LISTEN_PORT"
set_property "vpn.tls.enabled" "$ACTUAL_VPN_TLS"
set_property "vpn.connect.host" "$VPN_CONNECT_HOST"
set_property "vpn.connect.port" "$VPN_CONNECT_PORT"

[ -n "$VPN_KEY_FILE_PATH" ] && set_property "vpn.key.file.path" "$VPN_KEY_FILE_PATH"
[ -n "$VPN_KEY_PASSWORD" ] && set_property "vpn.key.password" "$VPN_KEY_PASSWORD"
[ -n "$VPN_TRUSTSTORE_FILE_PATH" ] && set_property "vpn.truststore.file.path" "$VPN_TRUSTSTORE_FILE_PATH"
[ -n "$VPN_TRUSTSTORE_PASSWORD" ] && set_property "vpn.truststore.password" "$VPN_TRUSTSTORE_PASSWORD"
[ -n "$TSP_JKS_FILE_PATH" ] && set_property "tsp.jks.file.path" "$TSP_JKS_FILE_PATH"
[ -n "$TSP_JKS_FILE_PASSWORD" ] && set_property "tsp.jks.file.password" "$TSP_JKS_FILE_PASSWORD"

set_property "cache.type" "$CACHE_TYPE"
[ -n "$CACHE_LOCAL_KEY_TTL_SECONDS" ] && set_property "cache.local.key.ttl.seconds" "$CACHE_LOCAL_KEY_TTL_SECONDS"
[ -n "$CACHE_LOCAL_CLEAR_INTERVAL_SECONDS" ] && set_property "cache.local.clear.interval.seconds" "$CACHE_LOCAL_CLEAR_INTERVAL_SECONDS"
[ -n "$CACHE_REDIS_HOST" ] && set_property "cache.redis.host" "$CACHE_REDIS_HOST"
[ -n "$CACHE_REDIS_PORT" ] && set_property "cache.redis.port" "$CACHE_REDIS_PORT"
[ -n "$CACHE_REDIS_PASSWORD" ] && set_property "cache.redis.password" "$CACHE_REDIS_PASSWORD"
[ -n "$CACHE_REDIS_DB" ] && set_property "cache.redis.db" "$CACHE_REDIS_DB"

[ -n "$METRICS_ENABLED" ] && set_property "metrics.server.enabled" "$METRICS_ENABLED"
[ -n "$METRICS_PORT" ] && set_property "metrics.server.listen.port" "$METRICS_PORT"
[ -n "$METRICS_IP" ] && set_property "metrics.server.listen.ip" "$METRICS_IP"

# Support any custom EIMZO_CFG_* environment variable
for var in $(env | grep -E '^EIMZO_CFG_' | awk -F= '{print $1}'); do
    val="$(eval echo \$$var)"
    clean_key="$(echo "$var" | sed 's/^EIMZO_CFG_//' | tr '[:upper:]' '[:lower:]' | tr '_' '.')"
    set_property "$clean_key" "$val"
done

# If $1 is "start", shift it so remaining arguments can be passed through
if [ "$1" = "start" ]; then
    shift
fi

# Ensure default JAVA_OPTS
JAVA_OPTS="${JAVA_OPTS:--Xms256m -Xmx512m -XX:+UseG1GC}"

LOGGING_CONFIG="${CONFIG_DIR}/logging.properties"
if [ ! -f "$LOGGING_CONFIG" ]; then
    LOGGING_CONFIG="/dev/null"
fi

echo "[e-imzo entrypoint] Starting e-imzo-server..."
echo "[e-imzo entrypoint] Config: ${TARGET_CONFIG} | Host: ${VPN_CONNECT_HOST}:${VPN_CONNECT_PORT} | Listen: ${LISTEN_IP}:${LISTEN_PORT} | TLS: ${ACTUAL_VPN_TLS}"

exec java \
    -Dfile.encoding=UTF-8 \
    -Djava.util.logging.config.file="${LOGGING_CONFIG}" \
    -Dproperties.filename="${TARGET_CONFIG}" \
    ${JAVA_OPTS} \
    -jar "${APP_DIR}/e-imzo-server.jar" \
    start \
    "$@"
