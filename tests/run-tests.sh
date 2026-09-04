#!/usr/bin/env bash

err() {
    printf '%s\n' "$*" >&2
}

assert_secret_exists_and_matches() {
    local secret="${1:?}"
    local expected_value="${2:?}"
    local additional_message="${3:-}"
    local exported_secret_file="${SECRETS_EXPORT_PATH}/${secret}"

    if [[ ! -f "${exported_secret_file}" ]]; then
        err "Failed asserting that secret ${secret} exists at ${exported_secret_file}"
        return 1
    fi

    local actual_value
    actual_value=$(<"${exported_secret_file}")
    if [[ "${actual_value}" != "${expected_value}" ]]; then
        err "Failed asserting that secret ${secret} matches the expected value."
        err "$(printf "Expected != Actual: '%s' != '%s'" "${expected_value}" "${actual_value}")"

        if [[ -n "${additional_message}" ]]; then
            err "${additional_message}"
        fi

        return 1
    fi

    return 0
}

assert_secret_not_exists() {
    local secret="${1:?}"
    local exported_secret_file="${SECRETS_EXPORT_PATH}/${secret}"

    if [[ -e "${exported_secret_file}" ]]; then
        err "Failed asserting that secret ${secret} does not exist at ${exported_secret_file}"
        return 1
    fi

    return 0
}

assert_environment_variable_exists_and_matches_value() {
    local var_name="${1:?}"
    local expected_value="${2:?}"
    local additional_message="${3:-}"

    if [[ "${!var_name}" != "${expected_value}" ]]; then
        err "$(printf "Failed asserting that environment variable '%s' matches the expected value '%s'" "${var_name}" "${expected_value}")"

        if [[ -n "${additional_message}" ]]; then
            err "${additional_message}"
        fi

        return 1
    fi

    return 0
}

test_primary_functionality_normalized_secrets() {
    echo "test_secret value_0" >"${SECRETS_EXPORT_PATH}/TEST_SECRET0"

    echo "should not be exported" >"${SECRETS_PATH}/test_secret0"
    echo "test_secret value_1" >"${SECRETS_PATH}/test_secret1"
    echo "test_secret value_2" >"${SECRETS_PATH}/test_secret2"
    echo "test_secret value_3" >"${SECRETS_PATH}/test_secret3"
    echo "test_secret value_4" >"${SECRETS_PATH}/TEST_SECRET4"

    ./src/init-docker-secrets-run.sh

    assert_secret_exists_and_matches "TEST_SECRET0" "test_secret value_0" "- Secret was probably overwritten" || return 1
    assert_secret_exists_and_matches "TEST_SECRET1" "test_secret value_1" || return 1
    assert_secret_exists_and_matches "TEST_SECRET2" "test_secret value_2" || return 1
    assert_secret_exists_and_matches "TEST_SECRET3" "test_secret value_3" || return 1
    assert_secret_exists_and_matches "TEST_SECRET4" "test_secret value_4" || return 1
}

test_primary_functionality_non_normalized_secrets() {
    echo "test_secret value_0" >"${SECRETS_PATH}/test_secret0"
    echo "test_secret value_1" >"${SECRETS_PATH}/test_secret1"
    echo "test_secret value_2" >"${SECRETS_PATH}/test_secret2"
    echo "test_secret value_3" >"${SECRETS_PATH}/test_secret3"
    echo "test_secret value_4" >"${SECRETS_PATH}/TEST_SECRET4"

    export NORMALIZE_SECRET_NAMES=0

    ./src/init-docker-secrets-run.sh

    assert_secret_exists_and_matches "test_secret0" "test_secret value_0" "- Secret was probably overwritten" || return 1
    assert_secret_exists_and_matches "test_secret1" "test_secret value_1" || return 1
    assert_secret_exists_and_matches "test_secret2" "test_secret value_2" || return 1
    assert_secret_exists_and_matches "test_secret3" "test_secret value_3" || return 1
    assert_secret_exists_and_matches "TEST_SECRET4" "test_secret value_4" || return 1
}

test_load_env() {
    source src/load-env.sh "${SECRETS_EXPORT_PATH}"

    assert_environment_variable_exists_and_matches_value TEST_SECRET0 "test_secret value_0" || return 1
    assert_environment_variable_exists_and_matches_value TEST_SECRET1 "test_secret value_1" || return 1
    assert_environment_variable_exists_and_matches_value TEST_SECRET2 "test_secret value_2" || return 1
    assert_environment_variable_exists_and_matches_value TEST_SECRET3 "test_secret value_3" || return 1
    assert_environment_variable_exists_and_matches_value TEST_SECRET4 "test_secret value_4" || return 1
}

test_missing_secrets_path() {
    local non_existent_path="${SECRETS_PATH}/nonexistent_dir"
    local export_path="${SECRETS_EXPORT_PATH}/export_check"

    SECRETS_PATH="${non_existent_path}" SECRETS_EXPORT_PATH="${export_path}" ./src/init-docker-secrets-run.sh || return 1

    if [[ -d "${export_path}" ]]; then
        err "Export directory should not have been created when secrets directory does not exist"
        return 1
    fi
}

test_empty_secrets_path() {
    ./src/init-docker-secrets-run.sh || return 1

    local count
    count=$(find "${SECRETS_EXPORT_PATH}" -maxdepth 1 -type f | wc -l)
    if [[ "${count}" -ne 0 ]]; then
        err "Export directory should be empty when secrets directory is empty"
        return 1
    fi
}

test_symlinks_and_hidden_files() {
    local target_dir
    target_dir="$(mktemp -d)"
    echo "symlink_value" >"${target_dir}/target_file"

    ln -s "${target_dir}/target_file" "${SECRETS_PATH}/linked_secret"
    echo "hidden_value" >"${SECRETS_PATH}/.hidden_secret"

    ./src/init-docker-secrets-run.sh

    rm -rf "${target_dir}"

    assert_secret_exists_and_matches "LINKED_SECRET" "symlink_value" || return 1
    assert_secret_not_exists ".HIDDEN_SECRET" || return 1
    assert_secret_not_exists ".hidden_secret" || return 1
}

test_duplicate_collision_skipping() {
    echo "first_value" >"${SECRETS_PATH}/dup_secret"
    echo "second_value" >"${SECRETS_PATH}/DUP_SECRET"

    ./src/init-docker-secrets-run.sh

    local count
    count=$(find "${SECRETS_EXPORT_PATH}" -maxdepth 1 -type f -name "DUP_SECRET" | wc -l)
    if [[ "${count}" -ne 1 ]]; then
        err "Expected exactly 1 DUP_SECRET export file"
        return 1
    fi
}

test_load_env_missing_directory() {
    if (source src/load-env.sh "/path/to/missing_directory_12345" 2>/dev/null); then
        err "Expected load-env.sh to fail on non-existent directory"
        return 1
    fi
}

test_load_env_invalid_identifiers() {
    echo "valid_val" >"${SECRETS_EXPORT_PATH}/VALID_VAR"
    echo "invalid_val" >"${SECRETS_EXPORT_PATH}/invalid-var-name"
    echo "invalid_val2" >"${SECRETS_EXPORT_PATH}/123_invalid_var"

    source src/load-env.sh "${SECRETS_EXPORT_PATH}" 2>/dev/null

    assert_environment_variable_exists_and_matches_value VALID_VAR "valid_val" || return 1
}

test_s6_export_path_mismatch_warning() {
    S6_RUNTIME_DIR="$(mktemp -d)"
    export S6_RUNTIME_DIR

    local output
    output=$(./src/init-docker-secrets-run.sh 2>&1)

    if [[ "${output}" != *"S6 Overlay detected, but SECRETS_EXPORT_PATH differs from default!"* ]]; then
        err "Expected S6 export path mismatch warning in output"
        err "Output was: ${output}"
        return 1
    fi
}

test_s6_export_path_default_no_warning() {
    S6_RUNTIME_DIR="$(mktemp -d)"
    export S6_RUNTIME_DIR

    local output
    output=$(SECRETS_PATH="/nonexistent_$$" SECRETS_EXPORT_PATH="/var/run/s6/container_environment/" ./src/init-docker-secrets-run.sh 2>&1)

    if [[ "${output}" == *"S6 Overlay detected, but SECRETS_EXPORT_PATH differs from default!"* ]]; then
        err "Did not expect S6 export path mismatch warning when using /var/run/s6/container_environment/"
        err "Output was: ${output}"
        return 1
    fi

    output=$(SECRETS_PATH="/nonexistent_$$" SECRETS_EXPORT_PATH="/run/s6/container_environment" ./src/init-docker-secrets-run.sh 2>&1)

    if [[ "${output}" == *"S6 Overlay detected, but SECRETS_EXPORT_PATH differs from default!"* ]]; then
        err "Did not expect S6 export path mismatch warning when using /run/s6/container_environment"
        err "Output was: ${output}"
        return 1
    fi
}

test_s6_keep_env_warning() {
    S6_RUNTIME_DIR="$(mktemp -d)"
    export S6_RUNTIME_DIR

    local output
    output=$(S6_KEEP_ENV=1 ./src/init-docker-secrets-run.sh 2>&1)

    if [[ "${output}" != *"S6_KEEP_ENV is set to 1"* ]]; then
        err "Expected S6_KEEP_ENV warning in output when S6_KEEP_ENV=1"
        err "Output was: ${output}"
        return 1
    fi

    output=$(S6_KEEP_ENV=true ./src/init-docker-secrets-run.sh 2>&1)

    if [[ "${output}" != *"S6_KEEP_ENV is set to 1"* ]]; then
        err "Expected S6_KEEP_ENV warning in output when S6_KEEP_ENV=true"
        err "Output was: ${output}"
        return 1
    fi
}

test_s6_keep_env_no_warning() {
    S6_RUNTIME_DIR="$(mktemp -d)"
    export S6_RUNTIME_DIR

    local output
    output=$(S6_KEEP_ENV=0 ./src/init-docker-secrets-run.sh 2>&1)

    if [[ "${output}" == *"S6_KEEP_ENV is set to 1"* ]]; then
        err "Did not expect S6_KEEP_ENV warning when S6_KEEP_ENV=0"
        err "Output was: ${output}"
        return 1
    fi

    output=$(./src/init-docker-secrets-run.sh 2>&1)

    if [[ "${output}" == *"S6_KEEP_ENV is set to 1"* ]]; then
        err "Did not expect S6_KEEP_ENV warning when S6_KEEP_ENV is unset"
        err "Output was: ${output}"
        return 1
    fi
}

reset_dirs() {
    if [[ -n "${S6_RUNTIME_DIR:-}" ]] && [[ -d "${S6_RUNTIME_DIR}" ]]; then
        rm -rf "${S6_RUNTIME_DIR}"
    fi
    unset S6_RUNTIME_DIR
    unset S6_KEEP_ENV

    rm -rf "${SECRETS_PATH}" "${SECRETS_EXPORT_PATH}"
    SECRETS_PATH="$(mktemp -d)"
    SECRETS_EXPORT_PATH="$(mktemp -d)"
    unset NORMALIZE_SECRET_NAMES
    export SECRETS_PATH SECRETS_EXPORT_PATH
}

main() {
    SECRETS_PATH="$(mktemp -d)"
    SECRETS_EXPORT_PATH="$(mktemp -d)"
    export SECRETS_PATH SECRETS_EXPORT_PATH

    trap 'rm -rf "${SECRETS_PATH}" "${SECRETS_EXPORT_PATH}" ${S6_RUNTIME_DIR:+"${S6_RUNTIME_DIR}"}' EXIT

    local failed_tests=0

    run_test() {
        local test_name="${1:?}"
        local should_reset="${2:-1}"

        if [[ "${should_reset}" -eq 1 ]]; then
            reset_dirs
        fi

        if ! "${test_name}"; then
            printf -- '- Test FAIL: %s\n' "${test_name}"
            ((failed_tests++))
        else
            printf -- '- Test OK: %s\n' "${test_name}"
        fi
    }

    run_test test_primary_functionality_normalized_secrets 1
    run_test test_load_env 0
    run_test test_primary_functionality_non_normalized_secrets 1
    run_test test_missing_secrets_path 1
    run_test test_empty_secrets_path 1
    run_test test_symlinks_and_hidden_files 1
    run_test test_duplicate_collision_skipping 1
    run_test test_load_env_missing_directory 1
    run_test test_load_env_invalid_identifiers 1
    run_test test_s6_export_path_mismatch_warning 1
    run_test test_s6_export_path_default_no_warning 1
    run_test test_s6_keep_env_warning 1
    run_test test_s6_keep_env_no_warning 1

    if [[ "${failed_tests}" -gt 0 ]]; then
        printf '\n'
        err "Some tests failed (${failed_tests} failure(s))"
        return 1
    fi

    printf '\nAll tests passed\n'
}

main "$@"
