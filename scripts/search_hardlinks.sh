#!/bin/bash

set -e


function parse_input_arguments {
    DIR="$(dirname "${BASH_SOURCE[0]}")"
    DIR="$(realpath "${DIR}")"

    if [[ ! -f "$1" || ! "${DIR}" =~ "/data/" ]]; then
        exit
    fi

    SRC="$(realpath "$1")"
    ROOT="${DIR%%/data/*}"
    DEST="${DIR}/hardlinks.json"

    READER="${DIR}/json_to_paths.jq"
    WRITER="${DIR}/json_from_kv.jq"
}


function search_hardlinks {
    while read -r line; do
        local file="$ROOT/$line"
        find "$ROOT" -samefile "$file" ! -path "$file"
    done <<< "$(cat)"
}


parse_input_arguments "$@"
# "$READER" "$SRC" | "$WRITER" > "$DEST"

search_hardlinks