#!/usr/bin/env bash


SOURCE="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "${SOURCE}")/../.."
ROOT="$(realpath "${ROOT}")"


source "${ROOT}/tests/helpers/json_tools.bash"
source "${ROOT}/tests/helpers/mock_servarr_event.bash"


common_setup() {
    load "${ROOT}/tests/bats-support/load"
    load "${ROOT}/tests/bats-assert/load"
    load "${ROOT}/tests/bats-file/load"
}
