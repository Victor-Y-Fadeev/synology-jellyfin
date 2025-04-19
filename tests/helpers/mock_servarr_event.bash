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


mock_servarr_event() {
    local event="$1"
    local event_type_json="$(jq 'to_entries[] | select(.key | endswith("arr_eventtype"))' "$event")"
    local event_type="$(jq --raw-output '.value' <<< "$event_type_json")"
    local servarr="$(jq --raw-output '.key | split("_") | .[0]' <<< "$event_type_json")"

    echo "$servarr"
    echo "$event_type"

    # unset_environment_variables
    # export_environment_variables "$1"
}




# unset_environment_variables
# export_environment_variables "$1"
# mock_servarr_event "../cases/tvdbid-72070/download/events/20250408_204316_743459087_Download.json"
# mock_servarr_event "../cases/tmdbid-18491/download/events/20250410_015320_350277224_Download.json"
mock_servarr_event "../cases/tvdbid-72070/download/events/20250408_204316_743459087_Download.json"
