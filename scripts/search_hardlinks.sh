#!/bin/bash

set -e


function parse_input_arguments {
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
        if [[ "$destination" =~ ^"$FILTER" ]]; then
            local file="${ROOT}/${destination#/}"
            local escape="$(printf '%q' "$file")"

            while read -r source; do
                if [[ -n "$source" ]]; then
                    echo "${source#"${ROOT}"}|${destination}"
                fi
            done <<< "$(find "$ROOT" -samefile "$file" ! -path "$escape" 2>/dev/null)"
        fi
    done <<< "$(cat)"
}


parse_input_arguments "$@"
"$READER" "$SRC" | search_hardlinks | "$WRITER" > "$DEST"
