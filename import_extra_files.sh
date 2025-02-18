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

            prefix="${#prefix}"
            postfix="${#postfix}"

            while read -r line; do
                if (( prefix + postfix < ${#line} )); then
                    output[$line]=".${line:prefix:-postfix}"
                fi
            done <<< "$value"
        fi
    done
}


function import_file {
    local source_path="$1"
    local destination_path="$2"

    if ln --force "$source_path" "$destination_path"; then
        echo "Hardlink '$source_path' => '$destination_path'"
    else
        cp --force "$source_path" "$destination_path"
        echo "Copy '$source_path' => '$destination_path'"
    fi
}


function search_extra_files {
    local source_path="$1"
    local source_folder="$(dirname "$source_path")"
    local source_file="$(basename "$source_path")"
    local source_name="${source_file%.*}"

    local source_file_escape="$(printf '%q' "$source_file")"
    local source_name_escape="$(printf '%q' "$source_name")"

    readarray -d '' array < <(find "$source_folder" -type f \
        -name "${source_name_escape}.*" ! -name "$source_file_escape" -print0)

    local -A dictionary
    for file in "${array[@]}"; do
        file_to_dictionary dictionary "$file"
    done

    local -A commentary
    dictionary_to_commentary dictionary commentary

    local destination_path="$2"
    local destination_absolute="${destination_path%.*}"

    for file in "${array[@]}"; do
        local extension="${file##*"$source_name"}"
        local suffix="${commentary[$file]}"

        import_file "$file" "${destination_absolute}${suffix}${extension}"
    done
}

# search_extra_files "$(realpath "$1")" "$(realpath "$2")"


import_file "/mnt/d/Desktop/synology-plex/link_test/1" "/mnt/c/Games/1"
# import_file "/mnt/d/Desktop/synology-plex/link_test/1" "/mnt/c/1"
import_file "/mnt/d/Desktop/synology-plex/link_test/1" "/mnt/d/Desktop/synology-plex/link_test/41"





case "$sonarr_eventtype" in
    "Download")
        if [[ ! -z "$sonarr_isupgrade" ]] ; then
            search_extra_files "$sonarr_episodefile_sourcepath" "$sonarr_episodefile_path"
        fi
        ;;
    "Rename")
        ;;
    "EpisodeFileDelete")
        ;;
esac
