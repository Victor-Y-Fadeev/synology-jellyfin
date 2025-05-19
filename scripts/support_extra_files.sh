#!/bin/bash

set -e


RADARR_BUFFER="/tmp/radarr_download_event.json"
SONARR_BUFFER="/tmp/sonarr_download_event.json"


###############################################################################
# Removes files with the same basename but different extensions.
#
# Handles parted and non-parted files with the following rules:
#   * Without part suffix - Only removes non-parted files, ignores all part files.
#   * With specific part suffix (.pt1, .pt2, etc.) - Removes only files with that exact suffix.
#   * With reserved .pt suffix - Removes ALL files with the same basename (both parted and non-parted).
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
###############################################################################
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


###############################################################################
# Removes all associated extra files for Servarr delete events.
#
# This function handles MovieFileDelete/EpisodeFileDelete events from
# Servarr by removing all files with the same basename but
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
#   Logs each removed file from remove_file_base
###############################################################################
function remove_extra_files {
    local base="${1%.*}"

    if [[ "$base" =~ \.pt[0-9]$ ]]; then
        base="${base%.pt[0-9]}.pt"
    fi

    remove_file_base "$base"
}


###############################################################################
# Renames files with the same basename but different extensions.
#
# Finds all files matching old_base.* and renames them to new_base.*
# while preserving their extensions.
# All destination directories should be already created by Servarr.
# Also removes empty directories after renaming.
#
# Note:
#   * File existence check required to handle cases with no extra files renaming,
#     when only one file was renamed by Servarr and function should do nothing.
#   * Directory existence check required to prevent errors with find command call,
#     when directory was deleted on previous call of this function. For example,
#     when there are no extra files and ALL regular files already renamed by Servarr.
#
# Arguments:
#   $1 - Old absolute basename path
#   $2 - New absolute basename path
# Outputs:
#   Logs each moved file
###############################################################################
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


###############################################################################
# Renames multiple files and their associated extra files.
#
# This function handles Rename events from Servarr
# by processing lists of old and new paths.
#
# Features:
#   * Preserves .pt[0-9] suffixes during file renaming.
#   * Reverts incorrect Servarr renaming of parted files.
#   * Deletes empty directories after renaming. This setting should be disabled
#     in Servarr to prevent external file deletion during directory renames,
#     like "Season 01" -> "Season 1".
#
# Note:
#   * Each element of BASH array has a trailing newline that must be
#     removed before passing to the mv command.
#
# Arguments:
#   $1 - Old file paths '|' delimited string
#   $2 - New file paths '|' delimited string
# Outputs:
#   Logs each moved file from rename_file_base
###############################################################################
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


###############################################################################
# Generates JSON mapping of found files to their computed extensions.
#
# This function searches for files with the same basename in all subdirectories
# starting from the given file's directory. It:
#   * Splits paths into segments and groups files by extension.
#   * Uses path segments starting from the original file directory.
#   * Uses all extensions after the original basename.
#   * Removes common subdirectories for files with the same extension.
#   * For single-file extension groups, removes additional extensions
#     except the original one.
#
# The output is a JSON dictionary where:
#   * Keys are absolute paths of found files.
#   * Values are computed extensions for import.
#
# Example filesystem structure:
#   - "/path/to/file.mkv"
#   - "/path/to/sound/first/file.mka"
#   - "/path/to/sound/second/file.mka"
#   - "/path/to/sound/third/file.language.mka"
#   - "/path/to/subtitles/first/file.mks"
#   - "/path/to/subtitles/first/spelling/file.mks"
#   - "/path/to/subtitles/second/file.mks"
#   - "/path/to/subtitles/third/file.language.srt"
#
# This generates the following JSON:
#   {
#     "/path/to/file.mkv": "mkv",
#     "/path/to/sound/first/file.mka": "first.mka",
#     "/path/to/sound/second/file.mka": "second.mka",
#     "/path/to/sound/third/file.language.mka": "language.mka",
#     "/path/to/subtitles/first/file.mks": "first.mks",
#     "/path/to/subtitles/first/spelling/file.mks": "first.spelling.mks",
#     "/path/to/subtitles/second/file.mks": "second.mks",
#     "/path/to/subtitles/third/file.language.srt": "language.srt"
#   }
#
# Arguments:
#   $1 - Absolute file path to use as base for depth search
# Outputs:
#   JSON string mapping found files to their computed extensions
###############################################################################
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


###############################################################################
# Creates a hard link or copies a file to a destination.
#
# Operation flow:
#   * Attempts to create a hard link from source to destination.
#   * Falls back to copying if hard linking fails.
#   * Preserves error messages from failed hard link operations.
#
# Arguments:
#   $1 - Source file path
#   $2 - Destination file path
# Outputs:
#   Logs the operation performed (hardlink or copy)
###############################################################################
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


###############################################################################
# Imports all associated extra files for Servarr download events.
#
# This function:
#   * Searches for files with the same basename across all subdirectories.
#   * Imports them to the destination with computed extensions.
#   * Handles multiple external audio and subtitle streams.
#   * Uses a naming scheme compatible with Jellyfin server format.
#   * Stores additional information using dots in the extension for different streams.
#
# Note:
#   * This function can be used directly to handle events if you don't need
#     the buffer feature.
#
# Arguments:
#   $1 - Source file path
#   $2 - Destination file path
# Outputs:
#   Logs each imported file from import_file
###############################################################################
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


###############################################################################
# Removes already buffered part file and renames others for consistency.
#
# This function corrects user mistakes during import events by:
#   * Fixing wrong part files for non-parted files.
#   * Handling cases when users reimport the same files to fix incorrectly numbering.
#   * Maintaining proper sequence of parted files on each call.
#
# Operation logic:
#   * Uses the third buffer array item containing back references.
#   * Reads the backref of the source file to check if it exists in buffered lists.
#   * If not found in buffer, does nothing.
#   * If list contains only one item, simply removes the file.
#   * If two files exist, removes one and renames the other by removing the .pt[0-9] suffix.
#   * If more files exist, skips files until the specified one, removes it, and renames remaining files.
#
# Note:
#   * Also renames/removes all external files associated with buffered ones
#     through rename_file_base/remove_file_base functions.
#   * Removed file disappears from the buffer JSON lists, but backref remains.
#
# Example with the following links:
#   - "/old/path/to/file_1.mkv" -> "/new/path/to/file.pt1.mkv"
#   - "/old/path/to/file_2.mkv" -> "/new/path/to/file.pt2.mkv"
#   - "/old/path/to/file_3.mkv" -> "/new/path/to/file.pt3.mkv"
#
# Changes when untracking "/old/path/to/file_2.mkv":
#   - "/new/path/to/file.pt1.mkv" -> Unchanged
#   - "/new/path/to/file.pt2.mkv" -> Removed
#   - "/new/path/to/file.pt3.mkv" -> Renamed to "/new/path/to/file.pt2.mkv"
#
# Arguments:
#   $1 - JSON buffer file path
#   $2 - Absolute source path to untrack
# Outputs:
#   Logs each renamed file from rename_file_base
#   Logs each removed file from remove_file_base
###############################################################################
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


###############################################################################
# Buffers imported files between script runs.
#
# This function:
#   * Maintains a buffer for parted files importing support.
#   * Creates and updates the buffer during download events for a movie or series.
#   * Invalidates the buffer when processing a different movie or series.
#   * Uses the movie or series base directory as an identifier for current buffer content.
#   * Stores all source paths used for each destination between script calls.
#   * Maintains back references for source files to prevent duplicate imports
#     and incorrect part file generation.
#
# Note:
#   * Uses the base of destination file path instead of the full path to support
#     cases where parts have different extensions.
#
# Example download events:
#   - "/path/to/downloads/s01e01.mkv" -> "/path/to/series/s01e01.mkv"
#   - "/path/to/downloads/s01e02.mkv" -> "/path/to/series/s01e02.mkv"
#   - "/path/to/downloads/s00e01.mkv" -> "/path/to/series/s00e01.mkv"
#   - "/path/to/downloads/s00e02.mp4" -> "/path/to/series/s00e01.mp4"
#
# Generated JSON buffer structure:
#   [
#     "/path/to/series",
#     {
#       "/path/to/series/s01e01": [
#         "/path/to/downloads/s01e01.mkv"
#       ],
#       "/path/to/series/s01e02": [
#         "/path/to/downloads/s01e02.mkv"
#       ],
#       "/path/to/series/s00e01": [
#         "/path/to/downloads/s00e01.mkv",
#         "/path/to/downloads/s00e02.mp4"
#       ]
#     },
#     {
#       "/path/to/downloads/s01e01.mkv": "/path/to/series/s01e01",
#       "/path/to/downloads/s01e02.mkv": "/path/to/series/s01e02",
#       "/path/to/downloads/s00e01.mkv": "/path/to/series/s00e01",
#       "/path/to/downloads/s00e02.mp4": "/path/to/series/s00e01"
#     }
#   ]
#
# Arguments:
#   $1 - JSON buffer file path
#   $2 - Movie or series base folder of Servarr
#   $3 - Destination file path without extension
#   $4 - Source file path
# Outputs:
#   Logs each renamed and removed file from untrack_buffered_part
###############################################################################
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


###############################################################################
# Processes download events with multi-part file support for Servarr.
#
# This function:
#   * Creates and updates a buffer between script runs to track multiple source files.
#   * Maintains import state since Servarr does not natively support multi-part files.
#   * Tracks files only for the current import sequence (clears on movie/series change).
#   * Processes all associated extra files for the current destination.
#
# Technical operation:
#   * Buffer stores information about source-destination relationships.
#   * When multiple sources are found for one destination,
#     Jellyfin compatible .pt[0-9] suffixes are applied.
#   * Each file is processed through import_extra_files after renaming.
#
# Usage guide:
#   * In Servarr manual import GUI, select multiple files for one destination.
#   * Ensure all desired files are checked in the interface.
#   * Disable "Delete Empty Folders" in Servarr settings to prevent conflicts.
#   * To reimport with different sources, clear the buffer first by:
#     - Importing a different movie/series.
#     - Deleting and re-adding the current movie/series.
#     - Restarting the container (automatically clears buffer).
#
# Arguments:
#   $1 - JSON buffer file path
#   $2 - Movie or series base folder of Servarr
#   $3 - Destination file path
#   $4 - Source file path
# Outputs:
#   Logs each hardlinked and copied file from import_file
#   Logs each renamed and removed file from buffer_download_event
###############################################################################
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
