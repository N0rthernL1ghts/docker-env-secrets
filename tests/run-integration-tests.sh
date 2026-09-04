#!/usr/bin/env bash

err() {
    printf '%s\n' "$*" >&2
}

info() {
    printf '%s\n' "$*"
}

readonly BASE_IMAGE="docker-env-secrets:integration-test"
readonly S6_TEST_IMAGE="docker-env-secrets-s6:integration-test"
readonly GENERIC_TEST_IMAGE="docker-env-secrets-generic:integration-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

cleanup() {
    info "Cleaning up integration test resources..."
    docker compose -f "${SCRIPT_DIR}/integration/s6-overlay/compose.yaml" down -v --rmi local >/dev/null 2>&1 || true
    docker compose -f "${SCRIPT_DIR}/integration/generic/compose.yaml" down -v --rmi local >/dev/null 2>&1 || true
    docker compose -f "${SCRIPT_DIR}/integration/no-secrets/compose.yaml" down -v >/dev/null 2>&1 || true
    docker rmi -f "${BASE_IMAGE}" >/dev/null 2>&1 || true
}

build_base_image() {
    info "Building base image ${BASE_IMAGE}..."
    if ! docker build -t "${BASE_IMAGE}" "${SCRIPT_DIR}/.."; then
        err "Failed to build base image ${BASE_IMAGE}"
        return 1
    fi
}

test_scenario_s6_overlay() {
    info "Running Scenario 1: With S6 Overlay..."
    local scenario_dir="${SCRIPT_DIR}/integration/s6-overlay"
    local compose_file="${scenario_dir}/compose.yaml"

    if ! docker build -t "${S6_TEST_IMAGE}" "${scenario_dir}"; then
        err "Failed to build S6 test image"
        return 1
    fi

    local output
    if ! output=$(docker compose -f "${compose_file}" up --abort-on-container-exit --exit-code-from test 2>&1); then
        err "S6 container execution failed:"
        err "${output}"
        docker compose -f "${compose_file}" down -v >/dev/null 2>&1 || true
        return 1
    fi

    docker compose -f "${compose_file}" down -v >/dev/null 2>&1 || true

    if [[ "${output}" != *"MATCH"* ]]; then
        err "S6 test failed: Expected secret was not present in with-contenv environment."
        err "Output was:"
        err "${output}"
        return 1
    fi

    info "Scenario 1 (With S6 Overlay) passed."
}

test_scenario_generic() {
    info "Running Scenario 2: Generic (Without S6 Overlay)..."
    local scenario_dir="${SCRIPT_DIR}/integration/generic"
    local compose_file="${scenario_dir}/compose.yaml"

    if ! docker build -t "${GENERIC_TEST_IMAGE}" "${scenario_dir}"; then
        err "Failed to build generic test image"
        return 1
    fi

    local output
    if ! output=$(docker compose -f "${compose_file}" up --abort-on-container-exit --exit-code-from test 2>&1); then
        err "Generic container execution failed:"
        err "${output}"
        docker compose -f "${compose_file}" down -v >/dev/null 2>&1 || true
        return 1
    fi

    docker compose -f "${compose_file}" down -v >/dev/null 2>&1 || true

    if [[ "${output}" != *"MATCH"* ]]; then
        err "Generic test failed: Expected secret was not loaded into environment."
        err "Output was:"
        err "${output}"
        return 1
    fi

    info "Scenario 2 (Generic) passed."
}

test_scenario_no_secrets() {
    info "Running Scenario 3: Zero Secrets Mounted..."
    local compose_file="${SCRIPT_DIR}/integration/no-secrets/compose.yaml"

    local output_s6
    if ! output_s6=$(docker compose -f "${compose_file}" up --abort-on-container-exit --exit-code-from s6-test s6-test 2>&1); then
        err "No-secrets S6 container execution failed:"
        err "${output_s6}"
        docker compose -f "${compose_file}" down -v >/dev/null 2>&1 || true
        return 1
    fi

    local output_generic
    if ! output_generic=$(docker compose -f "${compose_file}" up --abort-on-container-exit --exit-code-from generic-test generic-test 2>&1); then
        err "No-secrets Generic container execution failed:"
        err "${output_generic}"
        docker compose -f "${compose_file}" down -v >/dev/null 2>&1 || true
        return 1
    fi

    docker compose -f "${compose_file}" down -v >/dev/null 2>&1 || true

    local output="${output_s6}"$'\n'"${output_generic}"
    if [[ "${output}" != *"NO_SECRETS_S6_OK"* ]] || [[ "${output}" != *"NO_SECRETS_GENERIC_OK"* ]]; then
        err "No-secrets test failed: Expected output missing."
        err "Output was:"
        err "${output}"
        return 1
    fi

    info "Scenario 3 (Zero Secrets) passed."
}

main() {
    trap cleanup EXIT

    local failed_tests=0

    if ! build_base_image; then
        err "Base image build failed. Aborting integration tests."
        return 1
    fi

    if ! test_scenario_s6_overlay; then
        err "- Integration Test FAIL: Scenario with S6 Overlay"
        ((failed_tests++))
    else
        info "- Integration Test OK: Scenario with S6 Overlay"
    fi

    if ! test_scenario_generic; then
        err "- Integration Test FAIL: Scenario Generic (Without S6 Overlay)"
        ((failed_tests++))
    else
        info "- Integration Test OK: Scenario Generic (Without S6 Overlay)"
    fi

    if ! test_scenario_no_secrets; then
        err "- Integration Test FAIL: Scenario Zero Secrets"
        ((failed_tests++))
    else
        info "- Integration Test OK: Scenario Zero Secrets"
    fi

    if [[ "${failed_tests}" -gt 0 ]]; then
        printf '\n'
        err "Integration test suite failed (${failed_tests} failure(s))"
        return 1
    fi

    printf '\nAll integration tests passed successfully.\n'
}

main "$@"
