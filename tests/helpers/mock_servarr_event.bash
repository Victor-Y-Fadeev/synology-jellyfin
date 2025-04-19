#!/usr/bin/env bash


SOURCE="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "${SOURCE}")/../.."


unset_environment_variables() {
    local servarr="$(printenv | grep -i "arr_eventtype=" | sed 's/_.*//' | paste -sd '|')"

    while read -r line; do
        if [[ "$line" =~ ^(${servarr})_ ]]; then
            local variable="${line%%=*}"
            unset "$variable"
        fi
    done <<< "$(printenv)"
}


export_environment_variables() {
    local input="${1:-"$(cat)"}"
    if [[ -f "$input" ]]; then
        input="$(cat "$input")"
    fi

    local keys="$(jq --raw-output 'keys[]' <<< "$input")"
    while read -r key; do
        local value="$(jq --raw-output --arg key "$key" '.$key' <<< "$input")"
        export "$key"="$value"
    done <<< "$keys"
}


unset_environment_variables
export_environment_variables "$1"
# export_environment_variables "../cases/tvdbid-72070/download/events/20250408_204316_743459087_Download.json"
# export_environment_variables "../cases/tmdbid-18491/download/events/20250410_015320_350277224_Download.json"
