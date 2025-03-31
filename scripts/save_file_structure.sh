#!/bin/bash

set -e


MEDIA_EXTENSIONS="mkv|mp4|avi"
EXCLUDE_EXTENSIONS="jpg|png"


function parse_input_arguments {
    SRC="$(realpath "${1:-.}")"
    if [[ ! "$SRC" =~ "/data/" ]]; then
        exit
    fi

    DEPTH="$(echo "${SRC%%/data/*}" | tr -cd '/' | wc -c)"
    DEST="${SRC#*/data/}"
    DEST="${DEST%%/*}"

    if [[ "$DEST" == "downloads" ]]; then
        DEPTH=$(( DEPTH + 6 ))
    else
        DEPTH=$(( DEPTH + 5 ))
    fi

    DIR="$(dirname "$0")"
    DIR="$(realpath "$DIR")"
    DEST="${DIR}/${DEST}.json"
}


function find_unusual_folders {
    local extensions="(${MEDIA_EXTENSIONS}|${EXCLUDE_EXTENSIONS})"
    local escape="$(printf '%q' "$extensions")"
    find "$SRC" -type f ! -iregex ".*\.${escape}$" \
        | cut -d'/' -f1-"$DEPTH" | sort | uniq
}


function generate_file_structure {
    local extensions="(${EXCLUDE_EXTENSIONS})"
    local escape="$(printf '%q' "$extensions")"
    local json="{}"

    while read -r line; do
        local folder="/data/${line#*/data/}"
        local files="$(find "$line" -type f ! -iregex ".*\.${escape}$")"
        local value="{}"

        while read -r file; do
            local relative="${file#"${line}/"}"
            local subfolder="${relative%/*}"
            local name="${relative##*/}"

            if [[ "$name" == "$relative" ]]; then
                subfolder="."
            fi

            value="$(echo "$value" | jq -S '.[$key] += [$value]' \
                     --arg key "$subfolder" --arg value "$name")"
        done <<< "$files"

        json="$(echo "$json" | jq -S '.[$key] = $value' \
                --arg key "$folder" --argjson value "$value")"
    done <<< "$(find_unusual_folders)"

    echo "$json" > "$DEST"
}


parse_input_arguments "$@"
generate_file_structure
