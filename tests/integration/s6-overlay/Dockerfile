FROM scratch AS rootfs

COPY --chmod=0755 ["./verify.sh", "/verify.sh"]
COPY --from=ghcr.io/n0rthernl1ghts/s6-rootfs:3.2.0.2 ["/", "/"]
COPY --from=docker-env-secrets:integration-test ["/", "/"]



FROM alpine:3.24

RUN set -eux \
    && apk add --no-cache bash

COPY --from=rootfs ["/", "/"]

ENV S6_KEEP_ENV=0

ENTRYPOINT ["/init"]
CMD ["/verify.sh"]
