#!/command/with-contenv bash
# shellcheck shell=bash
set -euo pipefail

# Verify plain secret
if [[ "${S6_TEST_SECRET%$'\n'}" != "s6_secret_value_123" ]]; then
    printf 'Mismatch in S6_TEST_SECRET: got %q\n' "${S6_TEST_SECRET}" >&2
    exit 1
fi

# Verify collision secret was populated without crashing
if [[ -z "${COLLISION_SECRET:-}" ]]; then
    printf 'COLLISION_SECRET was not set\n' >&2
    exit 1
fi

# Verify multi-line and special characters secret
read -r -d '' EXPECTED_COMPLEX <<'EOF' || true
-----BEGIN TEST KEY-----
MIIEowIBAAKCAQEA0+special=chars&"quotes" and spaces!
line 2 of secret
-----END TEST KEY-----
EOF

if [[ "${COMPLEX_SECRET%$'\n'}" != "${EXPECTED_COMPLEX}" ]]; then
    printf 'Mismatch in COMPLEX_SECRET\n' >&2
    exit 1
fi

printf 'MATCH\n'
