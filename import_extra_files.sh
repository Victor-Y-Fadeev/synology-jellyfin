#!/bin/bash

set -e


function import_file {
    local source_path="${1}"
    local source_folder="$(dirname "${source_path}")"
    local source_filename="$(basename "${source_path}")"
    local source_escape_filename="$(printf "%q" "${source_filename}")"
    local source_escape_name="${source_escape_filename%.*}"

    local destination_path="${2}"
    local destination_folder="$(dirname "${destination_path}")"
    local destination_filename="$(basename "${destination_path}")"
    local destination_name="${destination_filename%.*}"

    # echo "${source_path}"
    # echo "${source_folder}"
    # echo "${source_filename}"
    # echo "${source_name}"

    # echo ${source_name:q}
    # echo "${source_name@Q}"

    # printf "%q" "${source_filename}"
    # # echo "find \"${source_folder}\" -type f -name \"*${source_name}.*\" ! -name \"${source_filename}\""
    # echo
    find "${source_folder}" -type f -name "*${source_escape_name}.*" ! -name "${source_escape_filename}"
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
