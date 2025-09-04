#!/bin/bash

set -e


INPUT="$(realpath "$1")"
BUFFER="${INPUT%.*}.json"

FROM="$2"
TO="$3"


if [[ ! -f "$BUFFER" ]]; then
    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time,pict_type -print_format json "$INPUT" > "$BUFFER"
fi





function show_buffer_frames {
    local input="$1"
    local output="${1%.*}.json"

    if [[ ! -f "$output" ]]; then
        # ffprobe -loglevel quiet -select_streams v:0 -show_packets -print_format json "$input" > "$output"
        # ffprobe -loglevel quiet -select_streams v:0 -show_frames -print_format json "$input" > "$output"
        ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time,pict_type -print_format json "$input" > "$output"
    fi

    cat "$output"
}


function select_k_seconds {
    jq --raw-output '[.frames[] | select(.pict_type | contains("I"))] | map(.pts_time) | .[]' <<< "$(cat)"
}


function time_to_seconds {
    local input="${1:-"$(cat)"}"

    local integer="${input%%.*}"
    local floating="${input##*.}"

    while [[ "$integer" =~ : ]]; do
        local major="${integer%%:*}"

    done
}


# K_SECONDS="$(show_buffer_frames "$INPUT" | select_k_seconds)"

