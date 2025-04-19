#!/usr/bin/env bash


SOURCE="$(realpath "${BASH_SOURCE[0]}")"
SCRIPTS="$(dirname "${SOURCE}")/../../scripts"


input_to_pipe() {
    local input="${1:-"$(cat)"}"

    if [[ -f "$input" ]]; then
        input="$(cat "$input")"
    fi

    echo "$input"
}


json_from_paths() {
    input_to_pipe "$1" | "${SCRIPTS}/json_from_paths.jq"
}


json_to_paths() {
    input_to_pipe "$1" | "${SCRIPTS}/json_to_paths.jq"
}


json_from_kv() {
    input_to_pipe "$1" | "${SCRIPTS}/json_from_kv.jq"
}


json_to_kv() {
    input_to_pipe "$1" | "${SCRIPTS}/json_to_kv.jq"
}
