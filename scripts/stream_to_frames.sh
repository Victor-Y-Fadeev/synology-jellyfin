#!/bin/bash

set -e


INPUT="$1"

if [[ "${INPUT}" =~ \.json$ ]]; then
    JSON="$(cat "${INPUT}")"
else
    JSON="$(ffprobe -loglevel quiet -select_streams v \
            -show_entries frame=pts_time,pict_type -print_format json "${INPUT}")"
fi

jq --raw-output '.frames | sort_by(.pts_time) | map(.pict_type) | add' <<< "${JSON}"
