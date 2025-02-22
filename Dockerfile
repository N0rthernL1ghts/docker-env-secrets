FROM scratch AS rootfs

COPY ["./rootfs/", "/"]
COPY --chmod=0777 ["./src/init-docker-secrets-run.sh", "/etc/s6-overlay/s6-rc.d/init-docker-secrets/run"]



FROM scratch

COPY --from=rootfs ["/", "/"]
