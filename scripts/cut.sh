#!/bin/bash

set -e


INPUT="$(realpath "$1")"
ENTRIES="${INPUT%.*}.json"
FRAMES="${INPUT%.*}.txt"

# FROM="$(date --date "1970-01-01T${2}Z" +%s.%N)"
# TO="$(date --date "1970-01-01T${3}Z" +%s.%N)"


if [[ ! -f "$ENTRIES" ]]; then
    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time,pict_type -print_format json "$INPUT" > "$ENTRIES"
fi

if [[ ! -f "$FRAMES" ]]; then
    cat "$ENTRIES" | jq --raw-output '.frames[] | select(.pict_type == "I") | .pts_time' > "$FRAMES"
fi

# cat "$ENTRIES" | jq --null-input --raw-output --stream 'first(fromstream(2 | truncate_stream(inputs)) | select(.pict_type=="I") | .pts_time)'


function next_key_frame {
    local input="$(realpath "${1}")"
    local time="$(date --date "1970-01-01T${2}Z" +%s.%N)"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time,pict_type -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "$time" '
            first(fromstream(2 | truncate_stream(inputs))
            | select(.pict_type == "I")
            | .pts_time
            | select(tonumber >= ($time | tonumber)))'
}

function next_key_packet {
    local input="$(realpath "${1}")"
    local time="$(date --date "1970-01-01T${2}Z" +%s.%N)"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries packet=pts_time,flags -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "$time" '
            first(fromstream(2 | truncate_stream(inputs))
            | select(.flags | contains("K"))
            | .pts_time
            | select(tonumber >= ($time | tonumber)))'
}


next_key_frame "$INPUT" "00:00:06.000"
next_key_packet "$INPUT" "00:00:06.000"

