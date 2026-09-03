#!/usr/bin/env bash

main() {
    local import_secrets_path="${1:?Path to import secrets directory is required}"
    local secret
    local var_name

    if [[ ! -d "${import_secrets_path}" ]]; then
        printf 'Error: Directory %s does not exist.\n' "${import_secrets_path}" >&2
        return 1
    fi

    while IFS= read -r -d '' secret; do
        var_name=$(basename "${secret}")

        if [[ ! "${var_name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            printf "Warning: Secret name '%s' is not a valid environment variable identifier. Skipping.\n" "${var_name}" >&2
            continue
        fi

        export "${var_name}=$(<"${secret}")"
    done < <(find -L "${import_secrets_path}" -maxdepth 1 -type f ! -name ".*" -print0)
}

main "$@"
