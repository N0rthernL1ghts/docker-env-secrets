#!/usr/bin/env bash
# File location: /etc/s6-overlay/s6-rc.d/init-docker-secrets/run

# init-docker-secrets main
main() {
    # This will prepend service name to all output from here
    exec > >(while read -r line; do echo "[init-docker-secrets] ${line}"; done) 2>&1

    local secretsPath="/run/secrets"
    local normalizedSecretsPath="/run/secrets_normalized"
    declare -A uniqueSecrets # Associative array to track normalized secret names

    mkdir -p "${normalizedSecretsPath}"

    # Check if the secrets directory is empty or does not exist
    if [ ! -d "${secretsPath}" ] || [ -z "$(find "${secretsPath}" -maxdepth 1 -type f)" ]; then
        printf "Warning: No secrets found in %s. Exiting.\n" "${secretsPath}"
        return 0
    fi

    # Use find to iterate over all secrets in the secrets directory
    find "${secretsPath}" -maxdepth 1 -type f | while read -r secretFile; do
        local secretName
        local normalizedSecretName
        secretName=$(basename "${secretFile}")
        normalizedSecretName="${secretName^^}"

        # Check for duplicate normalized secret names
        if [[ -n ${uniqueSecrets[${normalizedSecretName}]} ]]; then
            printf "Warning: The secret '%s' cannot be processed because it would overwrite the normalized name '%s'. This is not supported. Skipping this secret.\n" \
                "${secretName}" "${normalizedSecretName}"
            continue
        fi

        # Store the normalized secret name
        uniqueSecrets[${normalizedSecretName}]=1

        local normalizedSecretFile="${normalizedSecretsPath}/${normalizedSecretName}"

        # Copy the secret file and check for success
        if cp "${secretFile}" "${normalizedSecretFile}"; then
            printf "Copied secret %s to %s\n" "${secretName}" "${normalizedSecretFile}"
            continue
        fi

        printf "Error: Failed to copy secret %s to %s\n" "${secretName}" "${normalizedSecretFile}"

    done
}

main