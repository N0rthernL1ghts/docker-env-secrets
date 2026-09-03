#!/usr/bin/env bash
set -euo pipefail

export SECRETS_EXPORT_PATH=/tmp/exported_secrets
/usr/local/bin/init-docker-secrets
# shellcheck source=/dev/null
source /usr/local/lib/load-env "${SECRETS_EXPORT_PATH}"

if [[ "${GENERIC_SECRET:-}" == "generic_secret_value_456" ]]; then
    printf 'MATCH\n'
else
    printf 'MISMATCH\n' >&2
    exit 1
fi
