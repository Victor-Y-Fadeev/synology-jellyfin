#!/bin/bash

set -e


function parse_input_arguments {
    if [[ ! -f "$1" ]]; then
        exit
    fi

    SRC="$(realpath "$1")"
    JSON="$(cat "$SRC")"

    if [[ -z "$2" ]]; then
        DEST="$(realpath .)"
    else
        DEST="$(realpath "$2")"
    fi
}


function recursive_json_processing {
    local json="$1"
    local destination="$2"
    local type="$(echo "$json" | jq -r 'type')"
    local i

    case "$type" in
        "object")
            local keys="$(echo "$json" | jq 'keys')"
            local length="$(echo "$keys" | jq 'length')"

            for (( i = 0; i < length; ++i )); do
                local key="$(echo "$keys" | jq -r --argjson index "$i" '.[$index]')"
                local value="$(echo "$json" | jq --arg key "$key" '.[$key]')"

                recursive_json_processing "$value" "$destination/$key"
            done
            ;;

        "array")
            local length="$(echo "$json" | jq 'length')"

            for (( i = 0; i < length; ++i )); do
                local value="$(echo "$json" | jq --argjson index "$i" '.[$index]')"

                recursive_json_processing "$value" "$destination"
            done
            ;;

        "string")
            local value="$(echo "$json" | jq -r)"
            local absolute="$destination/$value"
            absolute="${absolute//"/./"/"/"}"
            absolute="${absolute//"//"/"/"}"

            local folder="$(dirname "$absolute")"
            local file="${absolute#"$DEST"}"

            mkdir --parents "$folder"
            echo "$file" > "$absolute"
            # echo "$file"
            ;;
    esac
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
        # echo "$line"
    done <<< "$list"
}


parse_input_arguments "$@"
# recursive_json_processing "$JSON" "$DEST"
flat_json_processing "$JSON" "$DEST"
