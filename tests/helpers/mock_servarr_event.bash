#!/usr/bin/env bash


SOURCE="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(dirname "${SOURCE}")/../.."


source "${ROOT}/tests/helpers/mock_radarr_event.bash"
source "${ROOT}/tests/helpers/mock_sonarr_event.bash"


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
    local input="$1"
    local keys="$(jq --raw-output 'keys[]' <<< "$input")"

    while read -r key; do
        local value="$(jq --raw-output --arg key "$key" '.$key' <<< "$input")"
        export "$key"="$value"
    done <<< "$keys"
}


get_source_path() {
    local input="$1"
    jq --raw-output '[with_entries(select(.key | test("_source")))[]] | min_by(length)' <<< "$input"
}


get_target_path() {
    local input="$1"
    jq --raw-output '[with_entries(select(.key | endswith("_path")))[]] | min_by(length)' <<< "$input"
}


add_path_prefix() {
    local input="$1"
    local origin="$2"
    local prefix="$3"

    if [[ -n "$prefix" && "$origin" != "null" ]]; then
        local escape="$(printf '%q' "$origin")"
        sed --posix --regexp-extended "s|${escape}|${prefix}/${origin#/}|g" <<< "$input"
    else
        echo "$input"
    fi
}


mock_servarr_event() {
    local event_environment="$(cat "$1")"
    local target_prefix="$2"
    local source_prefix="$3"

    local target_path="$(get_target_path "$event_environment")"
    local source_path="$(get_source_path "$event_environment")"

    event_environment="$(add_path_prefix "$event_environment" "$target_path" "$target_prefix")"
    event_environment="$(add_path_prefix "$event_environment" "$source_path" "$source_prefix")"

    unset_environment_variables
    export_environment_variables "$event_environment"

    mock_radarr_event
    mock_sonarr_event
}
