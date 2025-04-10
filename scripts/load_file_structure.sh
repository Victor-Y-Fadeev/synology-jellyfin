#!/bin/bash

set -e


function parse_input_arguments {
    if [[ ! -f "$1" ]]; then
        exit
    fi

    SRC="$(realpath "$1")"
    DEST="$(realpath "${2:-.}")"

    DIR="$(dirname "${BASH_SOURCE[0]}")"
    DIR="$(realpath "${DIR}")"
    SCRIPT="${DIR}/json_to_paths.jq"
}


function build_files_tree {
    local destination="$1"

    while read -r line; do
        local file="$destination/$line"
        local folder="$(dirname "$file")"

        mkdir --parents "$folder"
        echo "$line" > "$file"
    done <<< "$(cat)"
}


parse_input_arguments "$@"
"$SCRIPT" "$SRC" | build_files_tree "$DEST"
