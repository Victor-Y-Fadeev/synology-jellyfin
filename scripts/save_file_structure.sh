#!/bin/bash

set -e


MEDIA_EXTENSIONS="mkv|mp4|avi"
EXTERNAL_EXTENSIONS="nfo|ass|srt|mks|mka|ssa|mp3"
EXCLUDE_EXTENSIONS="jpg|png|webp|delete|txt|otf|ttf|PFB|PFM"


function parse_input_arguments {
    SRC="$(realpath "${1:-.}")"
    if [[ ! "${SRC}" =~ "/data/" ]]; then
        exit
    fi

    DEST="${SRC#*/data/}"
    DEST="${DEST%%/*}"

    DIR="$(dirname "${BASH_SOURCE[0]}")"
    DIR="$(realpath "${DIR}")"
    DEST="${DIR}/${DEST}.json"
    SCRIPT="${DIR}/json_from_paths.jq"
}


function find_unusual_folders {
    local extensions="(${MEDIA_EXTENSIONS}|${EXCLUDE_EXTENSIONS})"
    local escape="$(printf '%q' "$extensions")"

    find "$1" -type f ! -iregex ".*\.${escape}$" \
        | sed --posix --regexp-extended 's;(/(series|movies)(/[^/]*){2})/.*$;\1;' \
        | sort | uniq
}


function find_folder_files {
    local extensions="(${EXCLUDE_EXTENSIONS})"
    local escape="$(printf '%q' "$extensions")"

    while read -r line; do
        find "$line" -type f ! -iregex ".*\.${escape}$" \
            | sed --posix --regexp-extended 's|^.*(/data/)|\1|'
    done <<< "$(cat)"
}


parse_input_arguments "$@"
find_unusual_folders "$SRC" | find_folder_files | "$SCRIPT" > "$DEST"
