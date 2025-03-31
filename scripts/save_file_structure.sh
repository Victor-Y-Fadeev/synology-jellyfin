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


function generate_json_structure {
    local extensions="(${EXCLUDE_EXTENSIONS})"
    local escape_extensions="$(printf '%q' "$extensions")"
    local json="{}"

    while read -r line; do
        local escape_line="$(echo "$line" | sed 's|\W|\\\0|g')"
        local value="$(find "$line" -type f ! -iregex ".*\.${escape_extensions}$" \
            | sed --posix --regexp-extended "s|^${escape_line}/(.*)$|\"\1\"|" \
            | jq -s 'map((if contains("/") then sub("/[^/]*$"; "") else "." end) as $key
                         | {"key": $key, "value": ltrimstr($key + "/")})
                     | group_by(.key)
                     | map(.[0].key as $key | {"key": $key, "value": map(.value)})
                     | from_entries')"

        local folder="/data/${line#*/data/}"
        json="$(echo "$json" | jq -S '.[$key] = $value' \
                --arg key "$folder" --argjson value "$value")"
    done <<< "$(find_unusual_folders)"

    echo "$json" > "$DEST"
}


parse_input_arguments "$@"
generate_json_structure
