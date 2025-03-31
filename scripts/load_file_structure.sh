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
            echo "$file"
            ;;
    esac
}


# parse_input_arguments "$@"
# recursive_json_processing "$JSON" "$DEST"

# echo '{"path":["a", "b"]}' | jq 'walk(if type == "object" then with_entries(.key as $key | .value |= $key + .) else . end)'

# echo '{"path":["a", "b"]}' | jq 'recurse(if type == "object" then keys else . end, .|type == "array")'
# jq 'recurse(. * .; . < 20)'
# echo '[["a", "b"],3]' | jq 'recurse(if type == "array" then . else false end)'


# echo '["path",["a", "b", [1,2,5,3]]]' | jq 'walk(if type == "array" then .[] else . end)'
# echo '["path",["a", "b", [1,2,5,3]]]' | jq 'flatten'


# echo '{"path":["a", "b", {"1":["4","5"]}]}' | jq 'walk(if type == "object" then .[] else . end)'
# echo '{"path":["a", "b", {"1":["4","5"]}], "f": {"g":"4"}}' \
#     | jq 'walk(if type != "object" then .
#                else with_entries(.key as $key |
#                                  .value |= if type == "object" then with_entries(.key |= $key + .)
#                                            elif type == "string" then $key + . else . end) | .[] end)'

            #    .key as $key | .value | if type == "object" then with_entries(.key |= $key + .)

# echo '{"path":["a", "b", {"1":["4","5"]}], "f": {"g":"4"}}' \
#     | jq 'walk(if type != "object" then .
#                else with_entries(.key as $key |
#                                  .value |= if type == "object" then with_entries(.key |= $key + .)
#                                            elif type == "array" then map([{"key": $key, "value": .}] | from_entries) else $key + . end) | .[] end)'


# echo '{"path":["a", "b", {"1":["4","5"]}], "f": {"g":"4"}}' \
#     | jq 'walk(if type == "object" then .[] else . end)'


# echo '{"path":["a", "b", {"1":["4","5"]}], "f": {"g":"4"}}' \
#     | jq 'walk(if type != "object" then .
#                else with_entries(.key as $key |
#                                  .value |= if type == "array" then map([{"key": $key, "value": .}] | from_entries) else . end) end)'

# echo "{"a":["3"], "b":"4"}" | jq 'recurse(if type == "object" then .[] else . end, type != "object")'


# echo '{"path":["a", "b", {"1":["4","5"]}], "f": {"g":"4"}}' \
#     | jq 'walk(if type != "object" then .
#                else to_entries | .[] | .key as $key | .value
#                     | if type == "array" then map([{"key": $key, "value": .}] | from_entries) | .[]
#                       else [{"key": $key, "value": .}] | from_entries end end)'


# echo '{"path":["a", "b", {"1":["4","5"]}], "f": {"g":"4"}}' \
#     | jq 'walk(if type != "object" then .
#                else to_entries | .[] | .key as $key | .value
#                     | if type == "array" then .[] else . end
#                     | [{"key": $key, "value": .}] | from_entries end
#                | if type != "object" then .
#                  else to_entries | .[] | .key as $key | .value
#                       | if type != "object" then $key + "/" + .
#                         else with_entries(.key |= $key + "/" + .) end end)'



echo '[{"a":{".":["1", "2"], "b":["3", "4"]}, "c":{".":["5"]}}, {"path":["a", "b", {"1":["4","5"]}], "f": {"g":"4"}}]' \
    | jq 'walk(if type != "object" then .
               else to_entries | map(.key as $key | .value
                    | if type == "array" then .[] else . end
                    | [{"key": $key, "value": .}] | from_entries) end)'
            #    walk(if type != "object" then .
            #      else to_entries | .[]|.key as $key | .value
            #           | if type != "object" then $key + "/" + .
            #             else with_entries(.key |= $key + "/" + .) end end)'
