FROM busybox AS rootfs

COPY ["./rootfs/", "/rootfs/"]
COPY --chmod=0777 ["./src/init-docker-secrets-run.sh", "/rootfs/etc/s6-overlay/s6-rc.d/init-docker-secrets/run"]
COPY --chmod=0777 ["./src/init-docker-secrets-run.sh", "/rootfs/usr/local/bin/init-docker-secrets"]
COPY --chmod=0777 ["./src/load-env.sh", "/rootfs/usr/local/lib/load-env"]

# Replace interpreter with s6-overlay's /command/with-contenv
# For the sake of compatibility with non-s6-overlay based systems, /command/with-contenv is not default
RUN set -eux \
    && sed -i 's|#!/usr/bin/env bash|#!/command/with-contenv bash|' /rootfs/usr/local/bin/init-docker-secrets



FROM scratch

COPY --from=rootfs ["/rootfs/", "/"]

LABEL maintainer="Aleksandar Puharic <aleksandar@puharic.com>" \
      org.opencontainers.image.source="https://github.com/N0rthernL1ghts/docker-env-secrets" \
      org.opencontainers.image.description="Make secrets available as uppercase environment variables for seamless integration in Docker containers - Build ${TARGETARCH}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.2.0"
