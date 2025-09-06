#!/bin/bash

set -e

DELTA="30"

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


function next_key_packet {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries packet=pts_time,flags -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "$time" '
            first(fromstream(2 | truncate_stream(inputs))
            | select(.flags | contains("K"))
            | .pts_time
            | select(tonumber >= ($time | tonumber)))'
}

function next_key_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "$time" '
            first(inputs[1] | select(type == "string" and tonumber >= ($time | tonumber)))'
}

function next_key_frame_delta {
    local input="$1"
    local time="$2"
    local delta="${3:-$DELTA}"

    local end="0$(bc <<< "${time} + ${delta}")"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${time}%${end}" "${input}" \
        | jq --raw-output --arg time "$time" '.frames | map(.pts_time | tonumber | select(. >= ($time | tonumber))) | min'
}

function prev_key_frame {
    local input="$1"
    local time="$2"
    local delta="${3:-$DELTA}"

    local start="0$(bc <<< "if (${time} < ${delta}) 0 else ${time} - ${delta}")"
    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${start}%${time}" "${input}" \
        | jq --raw-output --arg time "$time" '.frames | map(.pts_time | tonumber) | max'
}


# time  next_key_packet "$INPUT" "06.000"
time  next_key_frame_delta "$INPUT" "0.6000"
time  next_key_frame "$INPUT" "0.6000"
# prev_key_frame "$INPUT" "10.6000"
# prev_key_frame "$INPUT" "30.03000" "5"

