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
    # echo "'$json'"

    case "$type" in
        "object")
            local keys="$(echo "$json" | jq 'keys')"
            local length="$(echo "$keys" | jq 'length')"

            for (( i = 0; i < length; ++i )); do
                # echo "'$type' '$i'"
                local key="$(echo "$keys" | jq -r --argjson index "$i" '.[$index]')"
                local value="$(echo "$json" | jq --arg key "$key" '.[$key]')"
                # echo "key='$key', value='$value'"
                recursive_json_processing "$value" "$destination/$key"
            done
            ;;

        "array")
            local length="$(echo "$json" | jq 'length')"

            for (( i = 0; i < length; ++i )); do
                # echo "'$type' '$i'"
                local value="$(echo "$json" | jq --argjson index "$i" '.[$index]')"
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


# length="3"
# for (( i = 0; i < length; ++i )); do
# # for ((i = 0; i < 2; i++)); do
#     echo "$i"
# done

recursive_json_processing '{"pa th":["a", "b"], "snd":["c", "d"]}' "."




# function B {
#     # local json="$1"
#     local type="$1"

#     if [[ "$type" == "object" ]]; then
#             local length=2
#             local i
#             for (( i = 0; i < length; ++i )); do
#                 echo "object" $i
#                 B "array"
#             done

#     elif [[ "$type" == "array" ]]; then
#             local length2=3
#             local i

#             for (( i = 0; i < length2; ++i )); do
#                 echo "array" $i
#             done
#     fi

# }

# B object

# function A() {
#     local iter=$1
#     local length=$2

#     case "object" in
#         "object")
#             for (( i = 0; i < length; ++i )); do
#                 echo $iter $i
#                 A $((iter + 1)) $i
#             done
#             ;;
#     esac
# }

# A 1 3
