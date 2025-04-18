#!/usr/bin/env bash
# File location: /etc/s6-overlay/s6-rc.d/init-docker-secrets/run

info() {
    echo "$*"
}

err() {
    info "$*" >&2
}

warn() {
    err "WARNING: $*"
}

# init-docker-secrets main
main() {
    # This will prepend service name to all output from here
    exec > >(while read -r line; do echo "[init-docker-secrets] ${line}"; done) 2>&1

    local secrets_path="${SECRETS_PATH:-/run/secrets/}"
    local secrets_export_path="${SECRETS_EXPORT_PATH:-/var/run/s6/container_environment/}"
    local normalize_secret_names="${NORMALIZE_SECRET_NAMES:-1}"
    declare -A unique_secrets # Associative array to track secret names

    mkdir -p "${secrets_export_path}"

    # Check if the secrets directory is empty or does not exist
    if [ ! -d "${secrets_path}" ]; then
        warn "Directory ${secrets_path} does not exist. Exiting."
        return 0
    fi

    if [ "${normalize_secret_names}" -eq 1 ]; then
        info "Normalizing secret names is enabled. Secrets will be exported in uppercase."
    else
        info "Normalizing secret names is disabled. Secrets will be exported as is."
    fi

    local total_secrets=0

    # Use find to iterate over all secrets in the secrets directory
    local secret_file
    while IFS= read -r -d '' secret_file; do
        local secret_name
        local export_secret_name
        secret_name=$(basename "${secret_file}")
        export_secret_name="${secret_name}"

        # Normalize secret names to uppercase if requested
        if [ "${normalize_secret_names}" -eq 1 ]; then
            export_secret_name="${secret_name^^}"
        fi

        local export_secret_file="${secrets_export_path}/${export_secret_name}"
        declare -A unique_secrets

        # Check for duplicate export secret names
        if [[ -f "${export_secret_file}" ]] || [[ -n ${unique_secrets[${export_secret_name}]} ]]; then
            warn "$(printf "The secret '%s' cannot be processed because it would overwrite the export name '%s'. This is not supported. Skipping this secret.\n" \
                "${secret_name}" "${export_secret_name}")"
            continue
        fi

        # Store the exported secret name
        unique_secrets[${export_secret_name}]=1

        # Copy the secret file and check for success
        if cp "${secret_file}" "${export_secret_file}"; then
            info "Copied secret ${secret_name} to ${export_secret_file}"
            ((total_secrets++))
            continue
        fi

        err "Error: Failed to copy secret ${secret_name} to ${export_secret_file}"

    done < <(find "${secrets_path}" -maxdepth 1 -type f -print0)

    if [ "${total_secrets}" -eq 0 ]; then
        warn "No secrets found in ${secrets_path}."
        return 0
    fi

    info "Successfully copied ${total_secrets} secrets to ${secrets_export_path}"
}

main
