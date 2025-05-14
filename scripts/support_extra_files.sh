#!/bin/bash

set -e


RADARR_BUFFER="/tmp/radarr_download_event.json"
SONARR_BUFFER="/tmp/sonarr_download_event.json"


#######################################
# Removes files with the same basename but different extensions.
#
# Handles parted and non-parted files with the following rules:
#   * Without part suffix - Only removes non-parted files, ignores all part files
#   * With specific part suffix (.pt1, .pt2, etc.) - Removes only files with that exact suffix
#   * With reserved .pt suffix - Removes ALL files with the same basename (both parted and non-parted)
#
# Example with the following file structure:
#   - "/path/to/file.mkv"
#   - "/path/to/file.mka"
#   - "/path/to/file.pt1.mkv"
#   - "/path/to/file.pt1.mka"
#   - "/path/to/file.pt2.mkv"
#   - "/path/to/file.pt2.mka"
#
# Behavior with different inputs:
#   - "/path/to/file" -> Removes "file.mkv" and "file.mka" only
#   - "/path/to/file.pt1" -> Removes "file.pt1.mkv" and "file.pt1.mka" only
#   - "/path/to/file.pt2" -> Removes "file.pt2.mkv" and "file.pt2.mka" only
#   - "/path/to/file.pt" -> Removes ALL files (both regular and part files)
#
# Arguments:
#   $1 - File path without extension to use as base for removal
# Outputs:
#   Logs each removed file
#######################################
function remove_file_base {
    local dir="$(dirname "$1")"
    local name="$(basename "$1")"
    local escape="$(sed 's|\W|\\\0|g' <<< "${name%.pt}")"

    while read -r file; do
        if [[ "$name" =~ \.pt[0-9]?$ || ! "$file" =~ \.pt[0-9]\. ]]; then
            rm --force "$file"
            echo "Remove '$file'"
        fi
    done <<< "$(find "$dir" -type f -name "${escape}.*")"
}


#######################################
# Removes all associated extra files for Radarr/Sonarr delete events.
#
# This function handles MovieFileDelete/EpisodeFileDelete events from
# Radarr/Sonarr by removing all files with the same basename but
# different extensions.
#
# Special handling is provided for part files:
#   * If the specified file has no part suffix (.pt1, .pt2, etc.),
#     all linked part-files will be ignored during deletion.
#   * This prevents accidental deletion of newly imported part-files
#     during the *FileDelete event generated at the end of importing.
#
# Arguments:
#   $1 - Absolute path to the file
# Outputs:
#   Logs each removed file
#######################################
function remove_extra_files {
    local base="${1%.*}"

    if [[ "$base" =~ \.pt[0-9]$ ]]; then
        base="${base%.pt[0-9]}.pt"
    fi

    remove_file_base "$base"
}


#######################################
# Renames files with the same basename but different extensions.
# Finds all files matching old_base.* and renames them to new_base.*
# while preserving their extensions.
#
# Arguments:
#   $1 - Old file path base
#   $2 - New file path base
# Outputs:
#   Logs each moved file
#   Removes empty directories
#######################################
function rename_file_base {
    local old_base="$1"
    local new_base="$2"

    local dir="$(dirname "$old_base")"
    local name="$(basename "$old_base")"
    local escape="$(sed 's|\W|\\\0|g' <<< "$name")"

    if [[ -d "$dir" ]]; then
        while read -r file; do
            if [[ -f "$file" ]]; then
                local extension="${file#"${old_base}"}"
                mv --force "$file" "${new_base}${extension}"
                echo "Move '$file' => '${new_base}${extension}'"
            fi
        done <<< "$(find "$dir" -type f -name "${escape}.*")"

        find "$dir" -type d -empty -delete
    fi
}


#######################################
# Renames multiple files and their associated extra files.
# Processes lists of old paths and new paths, handling special
# cases for .pt[0-9] part files.
#
# Arguments:
#   $1 - Pipe-delimited string of old file paths
#   $2 - Pipe-delimited string of new file paths
# Outputs:
#   Logs from rename_file_base
#######################################
function rename_extra_files {
    local old_paths
    readarray -d '|' -t old_paths <<< "$1"

    local new_paths
    readarray -d '|' -t new_paths <<< "$2"

    local i
    local length="${#old_paths[@]}"

    for (( i = 0; i < length; ++i )); do
        local old_base="${old_paths[$i]%.*}"
        local new_base="${new_paths[$i]%.*}"

        if [[ "$old_base" =~ \.pt[0-9]$ ]]; then
            old_base="${old_base%.pt[0-9]}"
            local extension="${old_paths[$i]#"${old_base}"}"
            mv --force "${new_paths[$i]%$'\n'}" "${new_base}${extension%$'\n'}"
        fi

        if [[ "$old_base" != "$new_base" ]]; then
            rename_file_base "$old_base" "$new_base"
        fi
    done
}


#######################################
# Generates JSON mapping of file extensions to their suffixes.
# Finds all files with the same base name and creates a structured
# JSON representation using jq.
#
# Arguments:
#   $1 - File path to use as base
# Outputs:
#   JSON string describing related files and their suffixes
#######################################
function generate_suffix_json {
    local dir="$(dirname "${1}")"
    local name="$(basename "${1%.*}")"

    local escape_dir="$(sed 's|\W|\\\0|g' <<< "$dir")"
    local escape_name="$(sed 's|\W|\\\0|g' <<< "$name")"

    find "$dir" -type f -name "${escape_name}.*" \
        | jq --arg dir "$escape_dir" --arg name "$escape_name" --raw-input --null-input '
            [
                inputs
                | capture("^(?<key>" + $dir
                        + "/?(?<value>.*)/" + $name
                        + "\\.(?<extension>.*))$")
                | .value |= split("/")
            ]
            | group_by(.extension)
            | map(until(map(.value[0]) | unique | [length != 1, any(. == null)] | any;
                        map(.value |= .[1:])) | .[])
            | map(.value += [.extension]
                | .value |= join("."))
            | from_entries'
}


#######################################
# Creates a hard link or copies a file to a destination.
# Tries to create a hard link first, falls back to copy if linking fails.
#
# Arguments:
#   $1 - Source file path
#   $2 - Destination file path
# Outputs:
#   Log message indicating operation performed
#######################################
function import_file {
    local source="$1"
    local destination="$2"

    if ln --force "$source" "$destination"; then
        echo "Hardlink '$source' => '$destination'"
    else
        cp --force "$source" "$destination"
        echo "Copy '$source' => '$destination'"
    fi
}


#######################################
# Imports all extra files associated with a given file.
# Uses generate_suffix_json to find related files and imports them
# to the destination with appropriate suffixes.
#
# Arguments:
#   $1 - Source file path
#   $2 - Destination file path
# Outputs:
#   Logs from import_file
#######################################
function import_extra_files {
    local source="$1"
    local destination="$2"

    local json="$(generate_suffix_json "$source")"
    local keys="$(jq --raw-output 'keys[]' <<< "$json")"
    local base="${destination%.*}"

    while read -r key; do
        local suffix="$(jq --raw-output --arg key "$key" '.[$key]' <<< "$json")"
        import_file "$key" "${base}.${suffix}"
    done <<< "$keys"
}


#######################################
# Removes or renames part files tracked in a buffer file.
# Handles special logic for multi-part files (.pt1, .pt2, etc).
#
# Arguments:
#   $1 - Buffer file path
#   $2 - Source file path to untrack
# Outputs:
#   Updates buffer file
#   Logs from remove_file_base and rename_file_base
#######################################
function untrack_buffered_part {
    local buffer="$1"
    local source="$2"

    local base="$(jq --raw-output --arg src "$source" '.[2][$src]' "$buffer")"
    if [[ "$base" != "null" ]]; then
        local length="$(jq --raw-output --arg base "$base" '.[1][$base] | length' "$buffer")"

        if (( length == 0 )); then
            return
        elif (( length == 1 )); then
            remove_file_base "$base"
        else
            local i=1
            local j=1

            local parts="$(jq --raw-output --arg base "$base" '.[1][$base][]' "$buffer")"
            while read -r part; do
                if [[ "$part" == "$source" ]]; then
                    remove_file_base "${base}.pt${i}"
                else
                    if (( length == 2 )); then
                        rename_file_base "${base}.pt${i}" "$base"
                    elif (( i != j )); then
                        rename_file_base "${base}.pt${i}" "${base}.pt${j}"
                    fi
                    (( ++j ))
                fi
                (( ++i ))
            done <<< "$parts"
        fi

        local updated="$(jq --arg base "$base" --arg src "$source" '.[1][$base] -= [$src]' "$buffer")"
        echo "$updated" > "$buffer"
    fi
}


#######################################
# Records download event information in a buffer file.
# Creates or updates buffer with instance, base, and source information.
#
# Arguments:
#   $1 - Buffer file path
#   $2 - Instance identifier
#   $3 - Base file path
#   $4 - Source file path
# Outputs:
#   Updates buffer file
#   Logs from untrack_buffered_part
#######################################
function buffer_download_event {
    local buffer="$1"
    local instance="$2"
    local base="$3"
    local source="$4"

    if [[ ! -f "$buffer" || "$(jq --raw-output '.[0]' "$buffer")" != "$instance" ]]; then
        echo "[\"$instance\"]" > "$buffer"
    fi

    untrack_buffered_part "$buffer" "$source"

    local updated="$(jq --arg base "$base" --arg src "$source" \
                        '.[1][$base] |= (. + [$src] | sort | unique)
                        | .[2][$src] = $base' "$buffer")"
    echo "$updated" > "$buffer"
}


#######################################
# Processes a download event for multi-part files.
# Updates buffer, renames files as needed, and imports associated files.
#
# Arguments:
#   $1 - Buffer file path
#   $2 - Instance identifier
#   $3 - Destination file path
#   $4 - Source file path
# Outputs:
#   Updates buffer file
#   Logs from import_extra_files
#######################################
function parted_download_event {
    local buffer="$1"
    local instance="$2"
    local destination="$3"
    local source="$4"

    local base="${destination%.*}"
    buffer_download_event "$buffer" "$instance" "$base" "$source"

    local parts="$(jq --raw-output --arg base "$base" '.[1][$base][]' "$buffer")"
    local length="$(wc --lines <<< "$parts")"

    local i=1
    while read -r part; do
        local extension="${part##*.}"
        if (( length > 1 )); then
            extension="pt${i}.${extension}"
        fi

        local full="${base}.${extension}"
        if [[ "$part" == "$source" && "$full" != "$destination" ]]; then
            rm --force "$full"
            mv --force "$destination" "$full"
        fi

        import_extra_files "$part" "$full"
        (( ++i ))
    done <<< "$parts"
}


case "$radarr_eventtype" in
    "MovieAdded")
        rm --force "$RADARR_BUFFER"
        ;;
    "Download")
        parted_download_event "$RADARR_BUFFER" "$radarr_movie_path" \
            "$radarr_moviefile_path" "$radarr_moviefile_sourcepath"
        ;;
    "Rename")
        rename_extra_files "$radarr_moviefile_previouspaths" "$radarr_moviefile_paths"
        ;;
    "MovieFileDelete")
        remove_extra_files "$radarr_moviefile_path"
        rm --force "$(dirname "$radarr_moviefile_path")/movie.nfo"
        ;;
    "MovieDelete")
        rm --force "$RADARR_BUFFER"
        ;;
esac


case "$sonarr_eventtype" in
    "SeriesAdd")
        rm --force "$SONARR_BUFFER"
        ;;
    "Download")
        if [[ -n "$sonarr_isupgrade" ]]; then
            parted_download_event "$SONARR_BUFFER" "$sonarr_series_path" \
                "$sonarr_episodefile_path" "$sonarr_episodefile_sourcepath"
        fi
        ;;
    "Rename")
        rename_extra_files "$sonarr_episodefile_previouspaths" "$sonarr_episodefile_paths"
        ;;
    "EpisodeFileDelete")
        remove_extra_files "$sonarr_episodefile_path"
        find "$(dirname "$sonarr_episodefile_path")" -type d -empty -delete
        ;;
    "SeriesDelete")
        rm --force "$SONARR_BUFFER"
        ;;
esac
