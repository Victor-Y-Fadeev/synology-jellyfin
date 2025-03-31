#!/bin/bash

set -e


function parse_input_arguments {
    if [[ ! -f "$1" ]]; then
        exit
    fi

    SRC="$(realpath "$1")"
    JSON="$(cat "$SRC")"
    DEST="$(realpath "${2:-.}")"
}


function flat_json_processing {
    local json="$1"
    local destination="$2"

    local list="$(echo "$JSON" | jq -r 'def builder(path; value): value |
        if type == "object" then
            to_entries | map(.key as $key | builder(path + "/" + $key; .value)) | .[]
        elif type == "array" then
            map(builder(path; .)) | .[]
        else
            path + "/" + .
        end; builder(""; .) | .[1:] | gsub("/\\.?/"; "/")')"

    while read -r line; do
        local file="$destination/$line"
        local folder="$(dirname "$file")"

        mkdir --parents "$folder"
        echo "$line" > "$file"
    done <<< "$list"
}


parse_input_arguments "$@"
flat_json_processing "$JSON" "$DEST"
