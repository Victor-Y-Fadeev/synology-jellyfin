#!/bin/bash

set -e



function add_file_to_map {
    local map="$1"
    local file="$2"
    local name="$(basename "$file")"
    # echo
    # echo "'${file}'"
    # echo

    # Use eval to check and update the associative array
    if eval "[[ -n \${${map}[${name}]} ]]" ; then
        eval "${map}[${name}]+='|${file}'"
        # echo 1
    else
        eval "${map}[${name}]='${file}'"
        # echo 0
    fi
}

# # Declare an associative array
# declare -A dictionary

# # Example usage: add files to the map
# add_file_to_map "dictionary" '/mnt/d/Desktop/synology-plex/data/downloads/Lodoss-tou Senki [BD] [720p]/RUS Sound/[Digital Force]/[Winter] Lodoss-tou Senki 07 [BDrip 960x720 x264 Vorbis].mka'
# add_file_to_map "dictionary" '/mnt/d/Desktop/synology-plex/data/downloads/Lodoss-tou Senki [BD] [720p]/RUS Sound/[SakaE & NesTea]/[Winter] Lodoss-tou Senki 07 [BDrip 960x720 x264 Vorbis].mka'
# add_file_to_map "dictionary" '/mnt/d/Desktop/synology-plex/data/downloads/Lodoss-tou Senki [BD] [720p]/RUS Subs/[Winter] Lodoss-tou Senki 07 [BDrip 960x720 x264 Vorbis].ass'

# # Accessing and displaying the contents of the map
# for key in "${!dictionary[@]}"; do
#     echo "$key -> ${dictionary[$key]}"
# done


# exit 0




# function add_file_to_map {
#     local map="${1}"
#     local file="${2}"
#     local name="$(basename "${file}")"
#     local escape_name="$(printf '%q' "${name}")"

#     if eval "[[ -n \${${map}[${escape_name}]} ]]" ; then
#         eval "${map}[${escape_name}]+='|${file}'"
#         echo 1
#     else
#         eval "${map}[${escape_name}]='${file}'"
#         echo 0
#     fi
# }

function import_file {
    local source_path="${1}"
    local source_folder="$(dirname "${source_path}")"
    local source_file="$(basename "${source_path}")"
    local source_escape_file="$(printf '%q' "${source_file}")"
    local source_escape_name="${source_escape_file%.*}"

    local destination_path="${2}"
    local destination_folder="$(dirname "${destination_path}")"
    local destination_filename="$(basename "${destination_path}")"
    local destination_name="${destination_filename%.*}"

    declare -A dictionary
    while read -d '' file ; do
        add_file_to_map dictionary "${file}"
    done < <(find "${source_folder}" -type f -name "${source_escape_name}.*" \
                ! -name "${source_escape_file}" -print0)

    for key in "${!dictionary[@]}"; do
        echo "$key -> ${dictionary[$key]}"
    done
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
