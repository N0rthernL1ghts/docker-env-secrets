FROM scratch AS rootfs
COPY --from=ghcr.io/n0rthernl1ghts/s6-rootfs:3.2.0.2 ["/", "/"]
COPY --from=docker-env-secrets:integration-test ["/", "/"]



FROM alpine:3.24

RUN set -eux \
    && apk add --no-cache bash

COPY --from=rootfs ["/", "/"]

ENV S6_KEEP_ENV=0

ENTRYPOINT ["/init"]
CMD ["/command/with-contenv", "bash", "-c", "VAL=\"${S6_TEST_SECRET%$'\\n'}\"; if [[ \"${VAL}\" == \"s6_secret_value_123\" ]]; then echo 'MATCH'; else echo 'MISMATCH'; exit 1; fi"]
