#!/bin/bash

set -e


function search_extra_files {
    local -n output="$1"
    local origin="$2"
    local levels="${3:-10}"

    local folder="$(dirname "$origin")"
    local file="$(basename "$origin")"

    local file_escape="$(printf '%q' "$file")"
    local name_escape="${file_escape%.*}"

    readarray -d '' output < <(find "$folder" -maxdepth "$levels" -type f \
        -name "${name_escape}.*" ! -name "$file_escape" -print0)
}


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


function import_extra_files {
    local source_path="$1"
    local source_name="$(basename "${source_path%.*}")"
    search_extra_files array "$source_path"

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


function rename_file {
    local old_path="$1"
    local old_absolute="${old_path%.*}"
    search_extra_files array "$old_path" 1

    local new_path="$2"
    local new_absolute="${new_path%.*}"

    for file in "${array[@]}"; do
        local postfix="${file##"$old_absolute"}"
        local destination="${new_absolute}${postfix}"

        mv --force "$file" "$destination"
        echo "Move '$file' => '$destination'"
    done
}


function rename_extra_files {
    readarray -d '|' -t old_paths <<< "$1"
    readarray -d '|' -t new_paths <<< "$2"

    local length="${#old_paths[@]}"

    for (( i = 0; i < length; ++i )); do
        rename_file "${old_paths[$i]}" "${new_paths[$i]}"
    done
}


function remove_extra_files {
    search_extra_files array "$1" 1

    for file in "${array[@]}"; do
        rm --force "$file"
        echo "Remove '$file'"
    done
}


case "$radarr_eventtype" in
    "Download")
        import_extra_files "$radarr_moviefile_sourcepath" "$radarr_moviefile_path"
        ;;
    "Rename")
        rename_extra_files "$radarr_moviefile_previouspaths" "$radarr_moviefile_paths"
        ;;
    "MovieFileDelete")
        remove_extra_files "$radarr_moviefile_path"
        ;;
esac


case "$sonarr_eventtype" in
    "Download")
        if [[ -n "$sonarr_isupgrade" ]]; then
            import_extra_files "$sonarr_episodefile_sourcepath" "$sonarr_episodefile_path"
        fi
        ;;
    "Rename")
        rename_extra_files "$sonarr_episodefile_previouspaths" "$sonarr_episodefile_paths"
        ;;
    "EpisodeFileDelete")
        remove_extra_files "$sonarr_episodefile_path"
        ;;
esac
