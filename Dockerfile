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
      org.opencontainers.image.authors="Abdumannon <0605AbMu@gmail.com>" \
      dev.dozzle.icon="data:image/png;base64,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"

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
