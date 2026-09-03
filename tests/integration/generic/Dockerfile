FROM alpine:3.24 AS rootfs

COPY --chmod=0755 ["./verify.sh", "/build-rootfs/verify.sh"]
COPY --from=docker-env-secrets:integration-test ["/", "/build-rootfs/"]

RUN set -eux \
    && rm -rf /etc/s6-overlay



FROM alpine:3.24

RUN set -eux \
    && apk add --no-cache bash

COPY --from=rootfs ["/build-rootfs/", "/"]

CMD ["/verify.sh"]