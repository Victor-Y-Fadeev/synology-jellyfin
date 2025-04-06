#!/bin/bash

set -e


function json_to_paths {
    local input="${1:-"$(cat)"}"
    local directory="$(dirname "${BASH_SOURCE[0]}")"
    local source="$directory/json_to_paths.jq"

    jq -r -f "$source" <<< "$input"
}


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if  (( $# > 0 )); then
        json_to_paths "$(cat "$1")"
    else
        json_to_paths
    fi
fi
