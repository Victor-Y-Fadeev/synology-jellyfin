#!/bin/bash

set -e


function file_to_dictionary {
    local -n map="$1"
    local -r file="$2"
    local -r name="$(basename "$file")"

    if [[ -n "${map[$name]}" ]]; then
        map[$name]+=$'\n'"$file"
    else
        map[$name]="$file"
    fi
}

function dictionary_to_commentary {
    local -n from="$1"
    local -n to="$2"

    for key in "${!from[@]}"; do
        # readarray -d '\n' -t list <<< "${from[$key]}"
        # echo "$(wc -l <<< "${from[$key]}")"
        local value="${from[$key]}"
        local count="$(wc -l <<< "$value")"

        if (( count > 1 )); then
            # echo "$key -> ${#list[@]}"
            # printf "abg\nabc\nabjuyuj\nab\nac4545\n" | sed -e 'N;s|^\(.*\).*\n\1.*$|\1\n\1|;D'
            # https://stackoverflow.com/questions/6973088/longest-common-prefix-of-two-strings-in-bash

            local prefix="$(sed -e 'N;s|^\(.*/\).*\n\1.*$|\1\n\1|;D' <<< "$value")"
            local postfix="$(sed -e 'N;s|^.*\(/.*\)\n.*\1$|\1\n\1|;D' <<< "$value")"

            # for line in "$(echo "$value")"; do
            #     # echo "${line#"$prefix"}"
            #     # echo "${line%"$postfix"}"
            #     echo "'$line'"
            # done
            while read -r line; do
                local comment="${line#"$prefix"}"
                comment="${comment%"$postfix"}"
                comment="$comment/$comment//$comment/$comment"
                comment="${comment//// }"
                echo "$comment"
            done <<< "$value"

            # echo "${value}"
            # echo "$prefix"
            # echo "$postfix"
            # sed 's/@@ /\n/g'
            # echo "${from[$key]//|/@@}"
            # echo 
            # echo -e "${from[$key]}"
        fi
    done
}


function import_file {
    local -r source_path="$1"
    local -r source_folder="$(dirname "$source_path")"
    local -r source_file="$(basename "$source_path")"
    local -r source_escape_file="$(printf '%q' "$source_file")"
    local -r source_escape_name="${source_escape_file%.*}"

    local -r destination_path="$2"
    local -r destination_folder="$(dirname "$destination_path")"
    local -r destination_filename="$(basename "$destination_path")"
    local -r destination_name="${destination_filename%.*}"

    readarray -d '' array < <(find "$source_folder" -type f -name "${source_escape_name}.*" \
                                ! -name "$source_escape_file" -print0)

    local -A dictionary
    for file in "${array[@]}"; do
        file_to_dictionary dictionary "$file"
    done

    local -A commentary
    dictionary_to_commentary dictionary commentary

    # for key in "${!dictionary[@]}"; do
    #     echo "$key -> ${dictionary[$key]}"
    # done
}

import_file "$(realpath "${1}")" "$(realpath "${2}")"


case "$sonarr_eventtype" in
    "Download")
        if [[ ! -z "$sonarr_isupgrade" ]] ; then
            import_file "$sonarr_episodefile_sourcepath" "$sonarr_episodefile_path"
        fi
        ;;
    "Rename")
        ;;
    "EpisodeFileDelete")
        ;;
esac
