#!/bin/bash

set -e


function file_to_dictionary {
    local -n map="$1"
    local file="$2"
    local name="$(basename "$file")"

    if [[ -n "${map[$name]}" ]]; then
        map[$name]+=$'\n'"$file"
    else
        map[$name]="$file"
    fi
}


function dictionary_to_commentary {
    local -n input="$1"
    local -n output="$2"

    for key in "${!input[@]}"; do
        local value="${input[$key]}"
        local count="$(wc -l <<< "$value")"

        if (( count > 1 )); then
            local prefix="$(sed -e 'N;s|^\(.*/\).*\n\1.*$|\1\n\1|;D' <<< "$value")"
            local postfix="$(sed -e 'N;s|^.*\(/.*\)\n.*\1$|\1\n\1|;D' <<< "$value")"

            # echo $prefix $postfix
            local prefix_length="${#prefix}"
            local postfix_length="${#postfix}"
            prefix="${#prefix}"
            postfix="${#postfix}"
            # echo $prefix_length $postfix_length

            while read -r line; do
                if (( prefix + postfix < ${#line} )); then
                    output[$line]="${line:prefix:-postfix}"
                fi

                # if (( prefix_length + postfix_length < ${#line} )); then
                #     to[$line]="${line:prefix_length:-postfix_length}"
                # fi


                # local comment="${line#"$prefix"}"
                # comment="${comment%"$postfix"}"
                # comment="${comment//// }"
                # to[$line]="$comment"

                # echo "'${line:$prefix_length}'"
                # if (( prefix_length + postfix_length < ${#line} )); then
                # echo "'${line:$prefix_length:-$postfix_length}'"
                # else
                # echo ''
                # fi
            done <<< "$value"
        fi
    done
}


# # function move_file {
#     local source_path="$1"
#     local destination_path="$2"
    
# # }


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

    local -A dictionary
    for file in "${array[@]}"; do
        file_to_dictionary dictionary "$file"
    done

    local -A commentary
    dictionary_to_commentary dictionary commentary

    for file in "${array[@]}"; do
        echo "'$file' -> '${commentary[$file]}'"
    done

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
