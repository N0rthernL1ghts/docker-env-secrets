FROM scratch AS rootfs

COPY ["./rootfs/", "/"]
COPY --chmod=0777 ["./src/init-docker-secrets-run.sh", "/etc/s6-overlay/s6-rc.d/init-docker-secrets/run"]



FROM scratch

COPY --from=rootfs ["/", "/"]

LABEL maintainer="Aleksandar Puharic <aleksandar@puharic.com>" \
      org.opencontainers.image.source="https://github.com/N0rthernL1ghts/docker-env-secrets" \
      org.opencontainers.image.description="Make secrets available as uppercase environment variables for seamless integration in Docker containers - Build ${TARGETARCH}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.0.0"
