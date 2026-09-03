FROM busybox AS rootfs

COPY ["./rootfs/", "/rootfs/"]
COPY --chmod=0755 ["./src/init-docker-secrets-run.sh", "/rootfs/usr/local/bin/init-docker-secrets"]
COPY --chmod=0755 ["./src/load-env.sh", "/rootfs/usr/local/lib/load-env"]

RUN set -eux \
    && rm -f /rootfs/etc/s6-overlay/s6-rc.d/init-docker-secrets/run \
    && printf '#!/command/with-contenv bash\nexec /usr/local/bin/init-docker-secrets "$@"\n' > /rootfs/etc/s6-overlay/s6-rc.d/init-docker-secrets/run \
    && chmod 0755 /rootfs/etc/s6-overlay/s6-rc.d/init-docker-secrets/run

FROM scratch

COPY --from=rootfs ["/rootfs/", "/"]

ARG TARGETARCH

LABEL maintainer="Aleksandar Puharic <aleksandar@puharic.com>" \
      org.opencontainers.image.source="https://github.com/N0rthernL1ghts/docker-env-secrets" \
      org.opencontainers.image.description="Make secrets available as uppercase environment variables for seamless integration in Docker containers - Build ${TARGETARCH}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.2.0"
