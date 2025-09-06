#!/bin/bash

set -e

DELTA="30"

INPUT="$(realpath "$1")"

# FROM="$(date --date "1970-01-01T${2}Z" +%s.%N)"
# TO="$(date --date "1970-01-01T${3}Z" +%s.%N)"


function next_key_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "$time" '
            first(inputs[1] | select(type == "string" and tonumber >= ($time | tonumber)))'
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


TIME="10.600"

next_key_frame "$INPUT" "$TIME"
prev_key_frame "$INPUT" "$TIME"
