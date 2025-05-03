#!/bin/bash

set -e


SONARR_BUFFER="/tmp/sonarr_download_event.json"
RADARR_BUFFER="/tmp/radarr_download_event.json"

SONARR_BUFFER="test_download_event.json"


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

    jq --raw-output --arg dest "$destination" '.[1][$dest][]' "$buffer"
}


buffer_download_event "$SONARR_BUFFER" \
    "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]" \
    "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]/Specials/s00e02 Neon Genesis Evangelion - The End of Evangelion.mkv" \
    "/data/downloads/series/anime/Neon Genesis Evangelion + The End of Evangelion/25. (The End of Evangelion) 01. AIR (Воздух).mkv"


buffer_download_event "$SONARR_BUFFER" \
    "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]" \
    "/data/series/anime/Neon Genesis Evangelion (1995) [tvdbid-70350]/Specials/s00e02 Neon Genesis Evangelion - The End of Evangelion.mkv" \
    "/data/downloads/series/anime/Neon Genesis Evangelion + The End of Evangelion/26. (The End of Evangelion) 02. My Pure Heart For You (Искренне Ваш...).mkv"
