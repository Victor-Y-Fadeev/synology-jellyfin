#!/bin/bash
# shellcheck disable=SC2086
#
# Info:
#   https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing and word splitting.

set -e


source "$(dirname "${BASH_SOURCE[0]}")/list_raw_streams.sh"

COMMON="-y -nostdin -hide_banner -loglevel warning -stats"
INPUT="$(realpath "$1")"
EXTENSION="$2"


function extract_video_stream {
    local input="$1"

    local json="$(show_streams "${input}")"
    local suffix="$(video_stream_suffix "${json}")"
    local output="${input%.*}.video.${suffix}.ts"

    ffmpeg $COMMON -i "${input}" -map v -c copy -f mpegts "${output}"
}

function extract_audio_stream {
    local input="$1"
    local index="$2"

    local json="$(show_streams "${input}")"
    json="$(audio_streams "${json}")"

    local suffix="$(audio_stream_suffix "${json}" "${index}")"
    local output="${input%.*}.audio$(printf '%02d' "${index}").${suffix}"

    json="$(jq --argjson idx "${index}" '.[$idx]' <<< "${json}")"
    local codec_name="$(jq --raw-output '.codec_name' <<< "${json}")"

    if [[ "${codec_name}" == "mp3" ]]; then
        ffmpeg $COMMON -i "${input}" -map "a:${index}" -c copy -f mp3 "${output}.mp3"
    elif [[ "${codec_name}" == "aac" ]]; then
        ffmpeg $COMMON -i "${input}" -map "a:${index}" -c copy -f adts "${output}.aac"
    elif [[ "${codec_name}" == "ac3" ]]; then
        ffmpeg $COMMON -i "${input}" -map "a:${index}" -c copy -f ac3 "${output}.ac3"
    elif [[ "${codec_name}" == "flac" ]]; then
        ffmpeg $COMMON -i "${input}" -map "a:${index}" -c copy -f flac "${output}.flac"
    elif [[ "${codec_name}" == "pcm_s16le" ]]; then
        ffmpeg $COMMON -i "${input}" -map "a:${index}" -c copy -f pcm_s16le "${output}.wav"
    fi
}

function extract_subtitle_stream {
    local input="$1"
    local index="$2"

    local json="$(show_streams "${input}")"
    json="$(subtitle_streams "${json}")"

    local suffix="$(subtitle_stream_suffix "${json}" "${index}")"
    local output="${input%.*}.subtitles$(printf '%02d' "${index}").${suffix}"

    json="$(jq --argjson idx "${index}" '.[$idx]' <<< "${json}")"
    local codec_name="$(jq --raw-output '.codec_name' <<< "${json}")"

    if [[ "${codec_name}" == "ass" ]]; then
        ffmpeg $COMMON -i "${input}" -map "s:${index}" -c copy -f ass "${output}.ass"
    elif [[ "${codec_name}" == "subrip" ]]; then
        ffmpeg $COMMON -i "${input}" -map "s:${index}" -c copy -f srt "${output}.srt"
    fi
}

function extract_streams {
    local input="$1"
    local json="$(show_streams "${input}")"

    # local video="$(video_streams "${json}")"
    # if (( $(streams_length "${video}") > 0 )); then
    #     extract_video_stream "${input}"
    # fi

    local audio="$(audio_streams "${json}")"
    audio="$(streams_length "${audio}")"
    audio="$((audio - 1))"

    for i in $(seq 0 "${audio}"); do
        extract_audio_stream "${input}" "${i}"
    done

    local subtitles="$(subtitle_streams "${json}")"
    subtitles="$(streams_length "${subtitles}")"
    subtitles="$((subtitles - 1))"

    for i in $(seq 0 "${subtitles}"); do
        extract_subtitle_stream "${input}" "${i}"
    done
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -d "${INPUT}" ]]; then
        apply_function "extract_streams" "${INPUT}" "${EXTENSION}"
    else
        extract_streams "${INPUT}"
    fi
fi
