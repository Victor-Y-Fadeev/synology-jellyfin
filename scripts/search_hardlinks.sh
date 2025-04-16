#!/bin/bash

set -e


function parse_input_arguments {
    DIR="$(dirname "${BASH_SOURCE[0]}")"
    DIR="$(realpath "${DIR}")"

    ROOT="$(realpath "${2:-"${DIR}"}")/"
    if [[ ! -f "$1" || ! "${ROOT}" =~ "/data/" ]]; then
        exit
    fi

    SRC="$(realpath "$1")"
    ROOT="${ROOT%%/data/*}"
    DEST="${DIR}/hardlinks.json"

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


parse_input_arguments "$@"
"$READER" "$SRC" | search_hardlinks | "$WRITER" > "$DEST"
