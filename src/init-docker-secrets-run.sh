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

    local secretsPath="${SECRETS_PATH:-/run/secrets/}"
    local normalizedSecretsPath="${NORMALIZED_SECRETS_PATH:-/var/run/s6/container_environment/}"
    declare -A uniqueSecrets # Associative array to track normalized secret names

    mkdir -p "${normalizedSecretsPath}"

    # Check if the secrets directory is empty or does not exist
    if [ ! -d "${secretsPath}" ]; then
        warn "Directory ${secretsPath} does not exist. Exiting."
        return 0
    fi

    local totalSecrets=0

    # Use find to iterate over all secrets in the secrets directory
    while IFS= read -r -d '' secretFile; do
        local secretName
        local normalizedSecretName
        secretName=$(basename "${secretFile}")
        normalizedSecretName="${secretName^^}"

        local normalizedSecretFile="${normalizedSecretsPath}/${normalizedSecretName}"
        declare -A uniqueSecrets

        # Check for duplicate normalized secret names
        if [[ -f "${normalizedSecretFile}" ]] || [[ -n ${uniqueSecrets[${normalizedSecretName}]} ]]; then
            warn "$(printf "The secret '%s' cannot be processed because it would overwrite the normalized name '%s'. This is not supported. Skipping this secret.\n" \
                "${secretName}" "${normalizedSecretName}")"
            continue
        fi

        # Store the normalized secret name
        uniqueSecrets[${normalizedSecretName}]=1

        # Copy the secret file and check for success
        if cp "${secretFile}" "${normalizedSecretFile}"; then
            info "Copied secret ${secretName} to ${normalizedSecretFile}"
            ((totalSecrets++))
            continue
        fi

        err "Error: Failed to copy secret ${secretName} to ${normalizedSecretFile}"

    done < <(find "${secretsPath}" -maxdepth 1 -type f -print0)

    if [ "${totalSecrets}" -eq 0 ]; then
        warn "No secrets found in ${secretsPath}."
        return 0
    fi

    info "Successfully copied ${totalSecrets} secrets to ${normalizedSecretsPath}"
}

main
