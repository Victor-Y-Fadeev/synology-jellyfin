#!/bin/bash

set -e


function file_to_dictionary {
    local -n map="$1"
    local file="$2"
    local name="$(basename "$file")"

    if [[ -n "${map["$name"]}" ]] ; then
        map["$name"]+="|$file"
    else
        map["$name"]="$file"
    fi
}

function dictionary_to_commentary {
    local -n from="${1}"
    local -n to="${2}"

    for key in "${!from[@]}"; do
        readarray -d '|' -t list <<< "${from[$key]}"

        if (( "${#list[@]}" > 1 )) ; then
            echo "$key -> ${#list[@]}"
        fi
    done
}


function import_file {
    local source_path="$1"
    local source_folder="$(dirname "$source_path")"
    local source_file="$(basename "$source_path")"
    local source_escape_file="$(printf '%q' "$source_file")"
    local source_escape_name="${source_escape_file%.*}"

    local destination_path="$2"
    local destination_folder="$(dirname "$destination_path")"
    local destination_filename="$(basename "$destination_path")"
    local destination_name="${destination_filename%.*}"

    readarray -d '' array < <(find "$source_folder" -type f -name "${source_escape_name}.*" \
                                ! -name "$source_escape_file" -print0)

    declare -A dictionary
    for file in "${array[@]}"; do
        file_to_dictionary dictionary "$file"
    done

    declare -A commentary
    dictionary_to_commentary dictionary commentary

    # for key in "${!dictionary[@]}"; do
    #     echo "$key -> ${dictionary[$key]}"
    # done
}

import_file "$(realpath "${1}")" "$(realpath "${2}")"


case "${sonarr_eventtype}" in
    "Download")
        if [[ ! -z "${sonarr_isupgrade}" ]] ; then
            import_file "${sonarr_episodefile_sourcepath}" "${sonarr_episodefile_path}"
        fi
        ;;
    "Rename")
        ;;
    "EpisodeFileDelete")
        ;;
esac
