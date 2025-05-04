#!/bin/bash

set -e


SONARR_BUFFER="/tmp/sonarr_download_event.json"
RADARR_BUFFER="/tmp/radarr_download_event.json"

# SONARR_BUFFER="test_download_event.json"


function generate_suffix_json {
    local dir="$(dirname "${1}")"
    local name="$(basename "${1%.*}")"

    local escape_dir="$(printf '%q' "$dir")"
    local escape_name="$(printf '%q' "$name")"

    find "$dir" -type f -name "${escape_name}.*" \
        | jq --arg dir "$escape_dir" --arg name "$escape_name" --raw-input '
            [
                inputs
                | capture("^(?<key>" + $dir
                        + "/?(?<value>.*)/" + $name
                        + "\\.(?<extension>[^\\.]*))$")
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

    echo "import_file '$source' '$destination'"
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
            echo "mv --force \"$destination\" \"$full\""
            # mv --force "$destination" "$full"
        fi

        # import_extra_files "$current" "$full"
    done
}


# parted_download_event "$SONARR_BUFFER" \
#     "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]" \
#     "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]/Specials/s00e02 Neon Genesis Evangelion - The End of Evangelion.mkv" \
#     "/data/downloads/series/anime/Neon Genesis Evangelion + The End of Evangelion/25. (The End of Evangelion) 01. AIR (Воздух).mkv"


# parted_download_event "$SONARR_BUFFER" \
#     "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]" \
#     "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]/Specials/s00e02 Neon Genesis Evangelion - The End of Evangelion.mkv" \
#     "/data/downloads/series/anime/Neon Genesis Evangelion + The End of Evangelion/26. (The End of Evangelion) 02. My Pure Heart For You (Искренне Ваш...).mkv"



origin="/mnt/d/Desktop/synology-jellyfin/scripts/data/downloads/series/anime/[Beatrice-Raws] Spice and Wolf [BDRip 1920x1080 x264 FLAC]/[Beatrice-Raws] Spice and Wolf 01 [BDRip 1920x1080 x264 FLAC].mkv"
# origin="/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]/Specials/s00e02 Neon Genesis Evangelion - The End of Evangelion.pt1.mkv"

dest="/data/series/anime/Spice and Wolf (2008) [tvdbid-81178]/Season 01/s01e01 Wolf and Best Clothes.mkv"

import_extra_files "$origin" "$dest"
