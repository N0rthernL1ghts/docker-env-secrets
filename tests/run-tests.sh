#!/usr/bin/env bash

err() {
    printf "%s\n" "$*" >&2
}

assert_secret_exists_and_matches() {
    local secret=${1:?}
    local expected_value="${2:?}"
    local additional_message="${3:-}"
    local exported_secret_file="${SECRETS_EXPORT_PATH}/${secret}"

    if [ ! -f "${exported_secret_file}" ]; then
        err "Failed asserting that secret ${secret} exists"
        return 1
    fi

    local actual_value
    actual_value=$(cat "${exported_secret_file}")
    if [ "${actual_value}" != "${expected_value}" ]; then
        err "Failed asserting that secret ${secret} matches the expected value."
        err "$(printf "Expected != Actual: '%s' != '%s'" "${expected_value}" "${actual_value}")"

        if [ -n "${additional_message}" ]; then
            err "${additional_message}"
        fi

        return 1
    fi

    return 0
}

assert_environment_variable_exists_and_matches_value() {
    local var_name=${1:?}
    local expected_value="${2:?}"
    local additional_message="${3:-}"

    if [ "${!var_name}" != "${expected_value}" ]; then
        err "$(printf "Failed asserting that environment variable '%s' matches the expected value '%s'" "${var_name}" "${expected_value}")"

        if [ -n "${additional_message}" ]; then
            err "${additional_message}"
        fi

        return 1
    fi

    return 0
}

test_primary_functionality_normalized_secrets() {
    # Create temporary directory names

    # Create secret file in the normalized secrets directory
    echo "test_secret value_0" >"${SECRETS_EXPORT_PATH}/TEST_SECRET0"

    # Create a secret files
    echo "should not be exported" >"${SECRETS_PATH}/test_secret0"
    echo "test_secret value_1" >"${SECRETS_PATH}/test_secret1"
    echo "test_secret value_2" >"${SECRETS_PATH}/test_secret2"
    echo "test_secret value_3" >"${SECRETS_PATH}/test_secret3"
    echo "test_secret value_4" >"${SECRETS_PATH}/TEST_SECRET4" # Should be able to handle this too

    # Run the script
    ./src/init-docker-secrets-run.sh

    assert_secret_exists_and_matches "TEST_SECRET0" "test_secret value_0" "- Secret was probably overwritten" || return 1
    assert_secret_exists_and_matches "TEST_SECRET1" "test_secret value_1" || return 1
    assert_secret_exists_and_matches "TEST_SECRET2" "test_secret value_2" || return 1
    assert_secret_exists_and_matches "TEST_SECRET3" "test_secret value_3" || return 1
    assert_secret_exists_and_matches "TEST_SECRET4" "test_secret value_4" || return 1
}

test_primary_functionality_non_normalized_secrets() {
    # Create temporary directory names

    # Create a secret files
    echo "test_secret value_0" >"${SECRETS_PATH}/test_secret0"
    echo "test_secret value_1" >"${SECRETS_PATH}/test_secret1"
    echo "test_secret value_2" >"${SECRETS_PATH}/test_secret2"
    echo "test_secret value_3" >"${SECRETS_PATH}/test_secret3"
    echo "test_secret value_4" >"${SECRETS_PATH}/TEST_SECRET4" # Should be able to handle this too

    export NORMALIZE_SECRET_NAMES=0

    # Run the script
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

main() {

    # Create temporary directory names

    SECRETS_PATH="$(mktemp -d)"
    SECRETS_EXPORT_PATH="$(mktemp -d)"

    export SECRETS_PATH SECRETS_EXPORT_PATH

    trap 'rm -rf "${SECRETS_PATH}" "${SECRETS_EXPORT_PATH}"' EXIT

    local failed_tests=0

    if ! test_primary_functionality_normalized_secrets; then
        echo "- Test FAIL: test_primary_functionality_normalized_secrets"
        ((failed_tests++))
    else
        echo "- Test OK: test_primary_functionality_normalized_secrets"
    fi

    if ! test_load_env; then
        echo "- Test FAIL: test_load_env"
        ((failed_tests++))
    else
        echo "- Test OK: test_load_env"
    fi

    # Regenerate temporary directories
    rm -rf "${SECRETS_PATH}" "${SECRETS_EXPORT_PATH}"
    SECRETS_PATH="$(mktemp -d)"
    SECRETS_EXPORT_PATH="$(mktemp -d)"
    export SECRETS_PATH SECRETS_EXPORT_PATH
    trap 'rm -rf "${SECRETS_PATH}" "${SECRETS_EXPORT_PATH}"' EXIT

    if ! test_primary_functionality_non_normalized_secrets; then
        echo "- Test FAIL: test_primary_functionality_non_normalized_secrets"
        ((failed_tests++))
    else
        echo "- Test OK: test_primary_functionality_non_normalized_secrets"
    fi

    if [ "${failed_tests}" -gt 0 ]; then
        printf "\n"
        err "Some tests failed"
        return 1
    fi

    printf "\nAll tests passed\n"
}

main
