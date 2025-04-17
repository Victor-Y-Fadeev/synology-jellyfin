#!/bin/bash

set -e


function setup_environment {
    DIR="$(dirname "${BASH_SOURCE[0]}")"
    DIR="$(realpath "${DIR}")"

    READER="${DIR}/json_to_paths.jq"
    WRITER="${DIR}/json_from_kv.jq"

    SRC="$(realpath "$1" 2>/dev/null)"
    if [[ -d "${SRC}" ]]; then
        ROOT="${SRC%%/data/*}"
    else
        ROOT="${DIR%%/data/*}"
    fi

    if [[ ! -e "${SRC}" || ! -d "${ROOT}/data" ]]; then
        exit
    fi
}


function search_hardlinks {
    while read -r destination; do
        local file="${ROOT}${destination#"${ROOT}"}"
        local escape="$(printf '%q' "$file")"

        while read -r source; do
            if [[ -n "$source" ]]; then
                echo "${source#"${ROOT}"}|${destination}"
            fi
        done <<< "$(find "$ROOT" -samefile "$file" ! -path "$escape" 2>/dev/null)"
    done <<< "$(cat)"
}


function get_id {
    local input="${1:-"$(cat)"}"
    sed --posix --regexp-extended 's|.*\[([a-z]+-[0-9]+)\].*|\1|; t; d' <<< "$input"
}


function process_paths {
    if [[ -f "$SRC" ]]; then
        local keys="$(jq -r 'keys[]' "$SRC")"
        local keys_count="$(wc -l <<< "$keys")"

        local ids="$(get_id "$keys")"
        local ids_count="$(wc -l <<< "$ids")"

        if [[ -n "$ids" && "$keys_count" == "$ids_count" ]]; then
            while read -r key; do
                local id="$(get_id "$key")"

                jq --arg key "$key" 'to_entries | map(select(.key == $key)) | from_entries' "$SRC" \
                    | "$READER" | search_hardlinks | "$WRITER" > "${DIR}/${id}.json"
            done <<< "$keys"
        else
            "$READER" "$SRC" | search_hardlinks | "$WRITER" > "${DIR}/hardlinks.json"
        fi
    else
        local id="$(get_id "$SRC")"
        find "$SRC" -type f | search_hardlinks | "$WRITER" > "${DIR}/${id:-hardlinks}.json"
    fi
}


setup_environment "$@"
process_paths
