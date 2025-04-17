#!/bin/bash

set -e


function setup_environment {
    DIR="$(dirname "${BASH_SOURCE[0]}")"
    DIR="$(realpath "${DIR}")"

    if [[ -d "$2" ]]; then
        FILTER="$(realpath "$2")"
        ROOT="${FILTER%%/data/*}"
        FILTER="${FILTER#"${ROOT}"}"
    else
        ROOT="${DIR%%/data/*}"
    fi

    if [[ ! -f "$1" || ! -d "${ROOT}/data" ]]; then
        exit
    fi

    SRC="$(realpath "$1")"
    DEST="${DIR}/hardlink_$(basename "${SRC}")"

    READER="${DIR}/json_to_paths.jq"
    WRITER="${DIR}/json_from_kv.jq"
}


function search_hardlinks {
    while read -r destination; do
        local file="${ROOT}/${destination#/}"
        local escape="$(printf '%q' "$file")"

        while read -r source; do
            if [[ -n "$source" ]]; then
                echo "${source#"${ROOT}"}|${destination}"
            fi
        done <<< "$(find "$ROOT" -samefile "$file" ! -path "$escape" 2>/dev/null)"
    done <<< "$(cat)"
}


function get_ids {
    sed --posix --regexp-extended 's|.*\[([a-z]+-[0-9]+)\].*|\1|; t; d' <<< "${1:-"$(cat)"}"
}


function process_input {
    if [[ -f "$SRC" ]]; then
        local keys="$(jq -r 'keys[]' "$SRC")"
        local keys_count="$(wc -l <<< "$keys")"

        local ids="$(get_ids <<< "$keys")"
        local ids_count="$(wc -l <<< "$ids")"

        if [[ -n "$ids" && "$keys_count" == "$ids_count" ]]; then
            while read -r key; do
                local id="$(get_ids <<< "$key")"

                jq --arg key "$key" 'to_entries | map(select(.key == $key)) | from_entries' "$SRC" \
                    | "$READER" | search_hardlinks | "$WRITER" > "${DIR}/${id}.json"
            done <<< "$keys"
        else
            "$READER" "$SRC" | search_hardlinks | "$WRITER" > "${DIR}/hardlinks_$(basename "${SRC}")"
        fi
    elif [[ "${SRC}" =~ (^|/)[a-z]+$ ]]; then
        echo "2 'hardlinks_${SRC##*/}.json'"
    elif [[ -n "$(get_ids <<< "$SRC")" ]]; then
        echo "3 '$(get_ids <<< "$SRC").json'"
    else
        echo "4 'hardlinks.json'"
    fi
}

# setup_environment "$@"
# "$READER" "$SRC" | search_hardlinks | "$WRITER" > "$DEST"
SRC="$1"
process_input
