#!/usr/bin/env bash

# Enable nullglob so the loop skips if there are no matching files
shopt -s nullglob

main() {
    local import_secrets_path="${1:?Path to import secrets directory is required}"
    local secret
    local var_name

    # Iterate over each file in the directory safely
    while IFS= read -r -d '' secret; do
        var_name=$(basename "${secret}")
        # Read file content efficiently while preserving whitespace/newlines and export the variable
        export "${var_name}=$(<"${secret}")"
    done < <(find "${import_secrets_path}" -type f -print0)
}
main "${@}"
