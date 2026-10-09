# syntax=docker/dockerfile:1

# ==============================================================================
# Stage 1: Builder (Extraction & Artifact Optimization)
# ==============================================================================
FROM alpine:3.22 AS builder

ARG ASSET_ZIP=""

WORKDIR /src

# Copy assets archive or directory
COPY assets/ /src/assets/

# Unpack archive and optimize libraries
RUN set -eux; \
    mkdir -p /build/lib /build/config /build/keys; \
    if [ -n "${ASSET_ZIP}" ]; then \
        if [ ! -f "/src/assets/${ASSET_ZIP}" ]; then \
            echo "Error: Specified ASSET_ZIP '/src/assets/${ASSET_ZIP}' does not exist!" >&2; \
            exit 1; \
        fi; \
        ZIP_PATH="/src/assets/${ASSET_ZIP}"; \
    else \
        ZIP_PATH=$(find /src/assets -maxdepth 1 -name "e-imzo-server-*.zip" -type f | head -n 1); \
    fi; \
    if [ -z "${ZIP_PATH}" ] || [ ! -f "${ZIP_PATH}" ]; then \
        echo "Error: No asset zip file found in /src/assets!" >&2; \
        exit 1; \
    fi; \
    echo "Unpacking target asset: ${ZIP_PATH}"; \
    unzip -q "${ZIP_PATH}" -d /tmp/unpacked; \
    APP_ROOT=$(find /tmp/unpacked -maxdepth 2 -name "e-imzo-server.jar" -exec dirname {} \; | head -n 1); \
    \
    # Copy core jar and configs \
    cp "${APP_ROOT}/e-imzo-server.jar" /build/; \
    if [ -f "${APP_ROOT}/config.properties" ]; then \
        cp "${APP_ROOT}/config.properties" /build/config/; \
    fi; \
    if [ -f "${APP_ROOT}/logging.properties" ]; then \
        cp "${APP_ROOT}/logging.properties" /build/config/; \
    fi; \
    \
    # Copy libraries and remove build/test artifacts not needed in production \
    # (testcontainers, junit, mockito, byte-buddy, docker-java, lombok, etc. save ~24MB) \
    cp -r "${APP_ROOT}/lib"/* /build/lib/; \
    rm -f \
        /build/lib/testcontainers-*.jar \
        /build/lib/junit-*.jar \
        /build/lib/mockito-*.jar \
        /build/lib/byte-buddy-*.jar \
        /build/lib/docker-java-*.jar \
        /build/lib/lombok-*.jar \
        /build/lib/hamcrest-*.jar \
        /build/lib/opentest4j-*.jar \
        /build/lib/apiguardian-*.jar \
        /build/lib/objenesis-*.jar \
        /build/lib/duct-tape-*.jar \
        /build/lib/commons-compress-*.jar \
        /build/lib/jna-*.jar \
        /build/lib/annotations-17*.jar

# ==============================================================================
# Stage 2: Production Minimal Runtime
# ==============================================================================
FROM amazoncorretto:8-alpine3.22-jre

ARG APP_VERSION="2.2.1"
ARG VCS_REF="local"
ARG BUILD_DATE=""

LABEL org.opencontainers.image.title="e-imzo-server" \
      org.opencontainers.image.description="E-IMZO Server - Electronic Digital Signature Verification Service" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/0605AbMu/e-imzo-server" \
      org.opencontainers.image.authors="Abdumannon <0605AbMu@gmail.com>"

ENV APP_DIR="/opt/e-imzo-server" \
    LANG="C.UTF-8" \
    TZ="Asia/Tashkent" \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"

# Install dumb-init for clean signal handling (PID 1) and tzdata for Tashkent timezone
RUN set -eux; \
    apk add --no-cache dumb-init tzdata; \
    addgroup -g 10001 -S eimzo; \
    adduser -u 10001 -S -G eimzo -h "${APP_DIR}" -s /sbin/nologin eimzo; \
    mkdir -p "${APP_DIR}/config" "${APP_DIR}/keys" "${APP_DIR}/lib"

WORKDIR ${APP_DIR}

# Copy optimized build artifacts from builder
COPY --from=builder /build/ ${APP_DIR}/

# Copy entrypoint script
COPY docker-entrypoint.sh /opt/e-imzo-server/docker-entrypoint.sh

# Ensure proper execution permissions and non-root ownership
RUN set -eux; \
    chmod +x /opt/e-imzo-server/docker-entrypoint.sh; \
    chown -R eimzo:eimzo "${APP_DIR}"

EXPOSE 8080 8081

VOLUME ["/opt/e-imzo-server/keys", "/opt/e-imzo-server/config"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -q -O - http://127.0.0.1:8080/info > /dev/null || exit 1

USER eimzo

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/opt/e-imzo-server/docker-entrypoint.sh"]
CMD ["start"]
