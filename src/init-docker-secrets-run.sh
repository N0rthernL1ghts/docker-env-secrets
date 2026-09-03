#!/usr/bin/env bash

info() {
    printf '%s\n' "$*"
}

err() {
    info "$*" >&2
}

warn() {
    err "WARNING: $*"
}

main() {
    exec > >(while IFS= read -r line; do printf '[init-docker-secrets] %s\n' "${line}"; done) 2>&1

    local secrets_path="${SECRETS_PATH:-/run/secrets/}"
    local secrets_export_path="${SECRETS_EXPORT_PATH:-/var/run/s6/container_environment/}"
    local normalize_secret_names="${NORMALIZE_SECRET_NAMES:-1}"
    local -A unique_secrets

    if [[ ! -d "${secrets_path}" ]]; then
        warn "Directory ${secrets_path} does not exist. Exiting."
        return 0
    fi

    mkdir -p "${secrets_export_path}"

    if [[ "${normalize_secret_names}" -eq 1 ]]; then
        info "Normalizing secret names is enabled. Secrets will be exported in uppercase."
    else
        info "Normalizing secret names is disabled. Secrets will be exported as is."
    fi

    local total_secrets=0
    local secret_file

    while IFS= read -r -d '' secret_file; do
        local secret_name
        local export_secret_name
        secret_name=$(basename "${secret_file}")
        export_secret_name="${secret_name}"

        if [[ "${normalize_secret_names}" -eq 1 ]]; then
            export_secret_name="${secret_name^^}"
        fi

        local export_secret_file="${secrets_export_path}/${export_secret_name}"

        if [[ -f "${export_secret_file}" ]] || [[ -n "${unique_secrets["${export_secret_name}"]:-}" ]]; then
            warn "$(printf "The secret '%s' cannot be processed because it would overwrite the export name '%s'. This is not supported. Skipping this secret." \
                "${secret_name}" "${export_secret_name}")"
            continue
        fi

        unique_secrets["${export_secret_name}"]=1

        if cp "${secret_file}" "${export_secret_file}"; then
            info "Copied secret ${secret_name} to ${export_secret_file}"
            ((total_secrets++))
            continue
        fi

        err "Error: Failed to copy secret ${secret_name} to ${export_secret_file}"
    done < <(find -L "${secrets_path}" -maxdepth 1 -type f ! -name ".*" -print0)

    if [[ "${total_secrets}" -eq 0 ]]; then
        warn "No secrets found in ${secrets_path}."
        return 0
    fi

    info "Successfully copied ${total_secrets} secrets to ${secrets_export_path}"
}

main "$@"
