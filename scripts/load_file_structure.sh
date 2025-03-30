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
    case "$type" in
        "object")
            echo "$type"
            ;;
        "array")
            local length="$(echo "$json" | jq 'length')"
            for (( i = 0; i < length; ++i )); do
                local value="$(echo "$json" | jq --arg index "$i" '.[$index | tonumber]')"
                recursive_json_processing "$value" "$destination"
            done
            ;;
        "string")
            local value="$(echo "$json" | jq -r)"
            local absolute="$destination/$value"
            local folder="$(dirname "$absolute")"

            # mkdir --parents "$folder"
            # echo "$absolute" > "$absolute"
            echo "$absolute"
            ;;
    esac
}


# jq 'map(type)' "$SRC"
# echo "$JSON" | jq 'if type == "object" then "object" elif type == "array" then "array" end'
# echo "{}" | jq 'type'
# echo "[]" | jq 'type'
# echo '""' | jq 'type'
# echo '' | jq 'type'
# echo '""' | jq '.'


# echo "'$SRC'"

# echo "'$DEST'"



# parse_input_arguments "$@"
# recursive_json_processing "$JSON" "$DEST"


# echo '{"path":["1", "2"], "path2":[]}' | jq 'keys' | jq 'length'
# echo '["a", "b"]' | jq --arg index 0 '.[$index | tonumber]'


#     for (( i = 0; i < length; ++i )); do
# for ((i = 0; i < 2; i++)); do
#     echo "$i"
# done

recursive_json_processing '["a", "b"]' "."