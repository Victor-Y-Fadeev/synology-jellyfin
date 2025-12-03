#!/bin/bash

set -e


COMMON="-y -nostdin -hide_banner -loglevel warning -stats"


function show_streams {
    local input="$1"
    ffprobe -loglevel quiet -show_streams -print_format json "${input}" | jq '.streams'
}

function video_streams {
    local json="$1"
    jq 'map(select(.codec_type == "video"))' <<< "${json}"
}

function audio_streams {
    local json="$1"
    jq 'map(select(.codec_type == "audio"))' <<< "${json}"
}

function subtitle_streams {
    local json="$1"
    jq 'map(select(.codec_type == "subtitle"))' <<< "${json}"
}

function streams_length {
    local json="$1"
    jq --raw-output 'length' <<< "${json}"
}

function stream_bit_rate {
    local json="$1"
    jq --raw-output '.bit_rate // (.tags | to_entries[]
        | select(.key | startswith("BPS")) | .value) // 0' <<< "${json}"
}

function stream_duration {
    local json="$1"
    jq --raw-output '.duration // (.tags | to_entries[]
        | select(.key | startswith("DURATION")) | .value) // 0' <<< "${json}"
}


function bit_rate_suffix {
    local json="$1"
    local bit_rate="$(stream_bit_rate "${json}")"

    local rate="$(bc --mathlib <<< "scale=0; (${bit_rate}) / 1000")"
    if (( rate > 0 )); then
        echo "${rate} Kbps"
    fi
}

function time_suffix {
    local json="$1"
    local duration="$(stream_duration "${json}")"

    if [[ -n "${duration}" ]]; then
        if [[ "${duration}" =~ : ]]; then
            local hours="${duration:0:2}"
            local minutes="${duration:3:2}"
            local seconds="${duration:6:2}"
        else
            local hours="$(bc --mathlib <<< "scale=0; (${duration}) / 3600")"
            local minutes="$(bc --mathlib <<< "scale=0; (${duration} % 3600) / 60")"
            local seconds="$(bc --mathlib <<< "scale=0; (${duration} % 60) / 1")"
        fi

        if (( hours > 0 )); then
            echo "${hours} h ${minutes} min ${seconds} s"
        elif (( minutes > 0 )); then
            echo "${minutes} min ${seconds} s"
        else
            echo "${seconds} s"
        fi
    fi
}

function common_stream_suffix {
    local json="$1"
    local suffix=""

    local time="$(time_suffix "${json}")"
    if [[ -n "${time}" ]]; then
        suffix="${suffix}, ${time}"
    fi

    local language="$(jq --raw-output '.tags.language' <<< "${json}")"
    if [[ -n "${language}" && "${language}" != "null" && "${language}" != "und" ]]; then
        suffix="${suffix}, ${language^}"
    fi

    local title="$(jq --raw-output '.tags.title' <<< "${json}")"
    if [[ -n "${title}" && "${title}" != "null" ]]; then
        suffix="${suffix}, ${title}"
    fi

    echo "${suffix}"
}

function video_stream_suffix {
    local json="$(video_streams "$1")"
    json="$(jq '.[0]' <<< "${json}")"

    local codec_long_name="$(jq --raw-output '.codec_long_name' <<< "${json}")"
    local frame_rate="$(jq --raw-output '.r_frame_rate' <<< "${json}")"
    local width="$(jq --raw-output '.width' <<< "${json}")"
    local height="$(jq --raw-output '.height' <<< "${json}")"

    local bit_rate="$(stream_bit_rate "${json}")"
    local bits_per_pixel="$(bc --mathlib <<< "scale=3; (${bit_rate}) / (${width} * ${height} * (${frame_rate}))")"
    if [[ "${bits_per_pixel}" =~ ^\. ]]; then
        bits_per_pixel="0${bits_per_pixel}"
    fi

    local rate="${frame_rate%/1}"
    if [[ "${rate}" =~ / ]]; then
        rate="$(bc --mathlib <<< "scale=3; ${frame_rate}")"
    fi

    local suffix="$(bit_rate_suffix "${json}")"
    suffix="${codec_long_name%% *}, ${width}x${height}, ${rate} fps, ${suffix}, ${bits_per_pixel} bpp"

    local common="$(common_stream_suffix "${json}")"
    echo "${suffix}${common}"
}

function audio_stream_suffix {
    local index="$2"
    local json="$(audio_streams "$1")"
    json="$(jq --argjson idx "${index}" '.[$idx]' <<< "${json}")"

    local codec_name="$(jq --raw-output '.codec_name' <<< "${json}")"
    local sample_rate="$(jq --raw-output '.sample_rate' <<< "${json}")"
    local channels="$(jq --raw-output '.channels' <<< "${json}")"
    local bit_rate="$(jq --raw-output '.bit_rate' <<< "${json}")"

    local hz="$(bc --mathlib <<< "scale=1; (${sample_rate}) / 1000")"
    local bit_rate="$(bit_rate_suffix "${json}")"
    local suffix="${codec_name^^}, ${channels} ch, ${hz} KHz, ${bit_rate}"

    local common="$(common_stream_suffix "${json}")"
    echo "${suffix}${common}"
}

function subtitle_stream_suffix {
    local index="$2"
    local json="$(subtitle_streams "$1")"
    json="$(jq --argjson idx "${index}" '.[$idx]' <<< "${json}")"

    local codec_long_name="$(jq --raw-output '.codec_long_name' <<< "${json}")"
    local suffix="${codec_long_name%% *}"

    local common="$(common_stream_suffix "${json}")"
    echo "${suffix}${common}"
}


function list_streams {
    local input="$1"
    local json="$(show_streams "${input}")"
    video_stream_suffix "${json}"

    local audio="$(audio_streams "${json}")"
    audio="$(streams_length "${audio}")"
    audio="$((audio - 1))"

    for i in $(seq 0 "${audio}"); do
        audio_stream_suffix "${json}" "${i}"
    done

    local subtitles="$(subtitle_streams "${json}")"
    subtitles="$(streams_length "${subtitles}")"
    subtitles="$((subtitles - 1))"

    for i in $(seq 0 "${subtitles}"); do
        subtitle_stream_suffix "${json}" "${i}"
    done
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    list_streams "${1}"
fi
