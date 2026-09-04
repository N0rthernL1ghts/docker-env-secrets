#!/usr/bin/env bash
set -euo pipefail

/usr/local/bin/init-docker-secrets

if [[ ! -d "${SECRETS_EXPORT_PATH}" ]]; then
    printf 'Custom export directory %s was not created\n' "${SECRETS_EXPORT_PATH}" >&2
    exit 1
fi
printf '  ✓ [OK] Custom export directory created\n'

# shellcheck source=/dev/null
source /usr/local/lib/load-env "${SECRETS_EXPORT_PATH}"

if [[ "${generic_secret:-}" != "generic_secret_value_456" ]]; then
    printf 'Mismatch in generic_secret\n' >&2
    exit 1
fi
printf '  ✓ [OK] Non-normalized secret generic_secret matched\n'

if [[ -n "${GENERIC_SECRET:-}" ]]; then
    printf 'GENERIC_SECRET should not be set when NORMALIZE_SECRET_NAMES=0\n' >&2
    exit 1
fi
printf '  ✓ [OK] Uppercase normalization inhibited (GENERIC_SECRET unset)\n'

if [[ "${lower_case_secret:-}" != "lower_case_value_789" ]]; then
    printf 'Mismatch in lower_case_secret\n' >&2
    exit 1
fi
printf '  ✓ [OK] Lowercase secret lower_case_secret matched\n'

read -r -d '' EXPECTED_COMPLEX <<'EOF' || true
-----BEGIN TEST KEY-----
MIIEowIBAAKCAQEA0+special=chars&"quotes" and spaces!
line 2 of secret
-----END TEST KEY-----
EOF

if [[ "${complex_secret:-}" != "${EXPECTED_COMPLEX}" ]]; then
    printf 'Mismatch in complex_secret\n' >&2
    exit 1
fi
printf '  ✓ [OK] Multi-line secret with special characters, quotes, and spaces matched\n'

printf 'MATCH\n'
