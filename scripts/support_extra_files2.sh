#!/bin/bash

set -e


RADARR_BUFFER="/tmp/radarr_download_event.json"
SONARR_BUFFER="/tmp/sonarr_download_event.json"


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


function import_extra_files {
    local source="$1"
    local destination="$2"

    local json="$(generate_suffix_json "$source")"
    local keys="$(jq --raw-output 'keys[]' <<< "$json")"
    local base="${destination%.*}"

    while read -r key; do
        local suffix="$(jq --arg key "$key" --raw-output '.[$key]' <<< "$json")"
        import_file "$key" "${base}.${suffix}"
    done <<< "$keys"
}


function buffer_download_event {
    local buffer="$1"
    local instance="$2"
    local destination="$3"
    local source="$4"

    if [[ ! -f "$buffer" || "$(jq --raw-output '.[0]' "$buffer")" != "$instance" ]]; then
        echo "[\"$instance\"]" > "$buffer"
    fi

    local updated="$(jq --arg dest "$destination" --arg src "$source" \
                        '.[1][$dest] |= (. + [$src] | sort | unique)' "$buffer")"
    echo "$updated" > "$buffer"

    jq --arg dest "$destination" --raw-output '.[1][$dest][]' "$buffer"
}


function parted_download_event {
    local buffer="$1"
    local instance="$2"
    local destination="$3"
    local source="$4"

    local all
    readarray all <<< "$(buffer_download_event "$buffer" "$instance" "$destination" "$source")"

    local i
    for (( i = 0; i < ${#all[@]}; ++i )); do
        local current="${all[$i]%$'\n'}"
        local extension="${current##*.}"

        if (( ${#all[@]} > 1 )); then
            extension="pt$(( i + 1 )).${extension}"
        fi

        local base="${destination%.*}"
        local full="${base}.${extension}"

        if [[ "$current" == "$source" && "$full" != "$destination" ]]; then
            mv --force "$destination" "$full"
        fi

        import_extra_files "$current" "$full"
    done
}


function rename_file_base {
    local old_base="$1"
    local new_base="$2"

    local dir="$(dirname "$old_base")"
    local name="$(basename "$old_base")"
    local escape="$(sed 's|\W|\\\0|g' <<< "$name")"

    while read -r file; do
        local extension="${file#"${old_base}"}"
        mv --force "$file" "${new_base}${extension}"
        echo "Move '$file' => '${new_base}${extension}'"
    done <<< "$(find "$dir" -type f -name "${escape}.*")"

    find "$dir" -type d -empty -delete
}


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


function remove_extra_files {
    local dir="$(dirname "${1}")"
    local name="$(basename "${1%.*}")"
    local escape="$(sed 's|\W|\\\0|g' <<< "${name%.pt[0-9]}")"

    while read -r file; do
        if [[ "$name" =~ \.pt[0-9]$ || ! "$file" =~ \.pt[0-9]\. ]]; then
            rm --force "$file"
            echo "Remove '$file'"
        fi
    done <<< "$(find "$dir" -type f -name "${escape}.*")"
}


case "$radarr_eventtype" in
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
esac


case "$sonarr_eventtype" in
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
esac
