#!/bin/bash

set -e


DELTA="30"
COMMON="-y -nostdin -hide_banner -loglevel warning -stats"

WORKDIR="$(realpath .)"
VIDEO_CONCAT="${WORKDIR}/video.txt"
SUBTITLES_OFFSET="0"

MERGE_INPUT=()
MERGE_STREAMS=()


function parse_arguments {
    INPUT="$1"
    FROM=()
    TO=()

    shift
    while read -r part; do
        if [[ "${part}" =~ \- ]]; then
            local from="${part%-*}"
            local to="${part#*-}"

            if [[ "${from}"  =~ : ]]; then
                FROM+=("$(date --date "1970-01-01T${from}Z" +%s.%N)")
            else
                FROM+=("${from:-0}")
            fi

            if [[ "${to}"  =~ : ]]; then
                TO+=("$(date --date "1970-01-01T${to}Z" +%s.%N)")
            else
                TO+=("${to}")
            fi
        fi
    done <<< "$(sed 's/[^0-9.:-]/\n/g' <<< "$@")"
}


function next_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "${time}" '
            first(inputs[1] | select(type == "string" and tonumber > ($time | tonumber)))'
}

function next_intra_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "${time}" '
            first(inputs[1] | select(type == "string" and tonumber >= ($time | tonumber)))'
}

function prev_intra_frame {
    local input="$1"
    local time="$2"

    local delta="${3:-$DELTA}"
    local start="0$(bc <<< "if (${time} < ${delta}) 0 else ${time} - ${delta}")"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${start}%${time}" "${input}" \
        | jq --raw-output --arg time "${time}" '.frames | map(.pts_time | tonumber) | max'
}

function prev_predicted_frame {
    local input="$1"
    local time="$2"

    local delta="${3:-$DELTA}"
    local start="0$(bc <<< "if (${time} < ${delta}) 0 else ${time} - ${delta}")"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time,pict_type -print_format json \
            -read_intervals "${start}%${time}" "${input}" \
        | jq --raw-output --arg time "${time}" '
            .frames | map(select(.pict_type == "I" or .pict_type == "P") | .pts_time | tonumber) | max'
}


function cut_video_recoding {
    local input="$1"
    local from="$2"
    local to="$3"

    local config="${WORKDIR}/video-${from}-${to}.txt"
    echo "file '${input}'" > "${config}"

    local prev="$(prev_intra_frame "${input}" "${from}")"
    echo "inpoint ${prev}" >> "${config}"

    local next="$(next_intra_frame "${input}" "${from}")"
    if [[ -n "${next}" ]]; then
        echo "outpoint ${next}" >> "${config}"
    fi

    local filter="trim=start=0$(bc <<< "${from} - ${prev}")"
    if [[ -n "${to}" ]]; then
        filter="${filter}:end=0$(bc <<< "${to} - ${prev}")"
    fi

    local output="${WORKDIR}/video-${from}-${to}.ts"
    ffmpeg $COMMON -f concat -safe 0 -i "${config}" \
        -map v -vf "${filter},setpts=PTS-STARTPTS" \
        -c libx264 -crf 1 -g 1 -f mpegts "${output}"

    echo "file '${output}'" >> "${VIDEO_CONCAT}"
}

function cut_video_copy {
    local input="$1"
    local from="$2"
    local to="$3"

    local config="${WORKDIR}/video-${from}-${to}.txt"
    echo "file '${input}'" > "${config}"

    echo "inpoint ${from}" >> "${config}"
    if [[ -n "${to}" ]]; then
        echo "outpoint ${to}" >> "${config}"
    fi

    local output="${WORKDIR}/video-${from}-${to}.ts"
    ffmpeg $COMMON -f concat -safe 0 -i "${config}" \
        -map v -c copy -f mpegts "${output}"

    echo "file '${output}'" >> "${VIDEO_CONCAT}"
}

function cut_video {
    local input="$1"
    local from="$2"
    local to="$3"

    local start="$(next_intra_frame "${input}" "${from}")"
    if [[ -z "${start}" ]] || { [[ -n "${to}" ]] && (( $(bc <<< "${to} <= ${start}") )) }; then
        cut_video_recoding "${input}" "${from}" "${to}"
        return
    elif (( $(bc <<< "${from} < ${start}") )); then
        cut_video_recoding "${input}" "${from}" "${start}"
    fi

    if [[ -z "${to}" ]]; then
        cut_video_copy "${input}" "${start}"
        return
    fi

    local prev="$(prev_predicted_frame "${input}" "${to}")"
    local end="$(next_frame "${input}" "${prev}")"
    if (( $(bc <<< "${start} < ${prev}") )); then
        cut_video_copy "${input}" "${start}" "${end}"
    fi

    if (( $(bc <<< "${end} < ${to}") )); then
        cut_video_recoding "${input}" "${end}" "${to}"
    fi
}

function cut_audio {
    local input="$1"
    local from="$2"
    local to="$3"

    local segment="-ss ${from}"
    if [[ -n "${to}" ]]; then
        segment="${segment} -to ${to}"
    fi

    local streams="$(ffprobe -loglevel quiet -select_streams a -show_entries stream=codec_name \
                    -print_format json "${input}" | jq --raw-output '.streams[] | .codec_name')"

    local i=0
    while read -r stream; do
        local base="${WORKDIR}/audio$(printf '%02d' "${i}")"
        local output="${base}-${from}-${to}"

        if [[ "${stream}" == "mp3" ]]; then
            ffmpeg $COMMON -i "${input}" $segment -map "a:${i}" -c copy -f mp3 "${output}.mp3"
            cat "${output}.mp3" >> "${base}.mp3"
        elif [[ "${stream}" == "aac" ]]; then
            ffmpeg $COMMON -i "${input}" $segment -map "a:${i}" -c copy -f adts "${output}.aac"
            cat "${output}.aac" >> "${base}.aac"
        elif [[ "${stream}" == "ac3" ]]; then
            ffmpeg $COMMON -i "${input}" $segment -map "a:${i}" -c copy -f ac3 "${output}.ac3"
            cat "${output}.ac3" >> "${base}.ac3"
        elif [[ "${stream}" == "flac" ]]; then
            ffmpeg $COMMON -i "${input}" $segment -map "a:${i}" -c pcm_s16le "${output}.wav"
            echo "file '${output}.wav'" >> "${base}.txt"
        fi

        (( ++i ))
    done <<< "${streams}"
}

function cut_subtitles_common {
    local input="$1"
    local stream="$2"

    local output="${WORKDIR}/subtitles$(printf '%02d' "${stream}").ass"
    echo "${output}"

    if [[ ! -f "${output}" ]]; then
            ffmpeg $COMMON -i "${input}" -map "s:${stream}" -c ass "${output}"

            local header="$(sed            '/^\[Events\]/, $d'         "${output}")"
            local format="$(sed         '1, /^\[Events\]/d; /^\[/, $d' "${output}" | head --lines 1)"
            local footer="$(sed --quiet '1, /^\[Events\]/d; /^\[/, $p' "${output}")"

            echo "${header}" > "${output}"
            echo "${footer}" >> "${output}"

            echo "[Events]" >> "${output}"
            echo "${format}" >> "${output}"
    fi
}

function cut_subtitles {
    local input="$1"
    local from="$2"
    local to="$3"

    local offset="${SUBTITLES_OFFSET}"
    local segment="-ss ${from}"

    if [[ -n "${to}" ]]; then
        SUBTITLES_OFFSET="$(bc <<< "${SUBTITLES_OFFSET} + ${to} - ${from}")"
        segment="${segment} -to ${to}"
    fi

    local count="$(ffprobe -loglevel quiet -select_streams s -show_entries stream=codec_name \
                    -print_format json "${input}" | jq --raw-output '.streams | length - 1')"

    for i in $(seq 0 $count); do
        local common="$(cut_subtitles_common "${input}" "${i}")"
        local cut="${common%.*}-${from}-${to}.ass"
        local final="${cut%.*}-offset.ass"

        ffmpeg $COMMON -i "${input}" $segment -map "s:${i}" -c ass "${cut}"
        ffmpeg $COMMON -itsoffset "${offset}" -i "${cut}" -map s -c ass "${final}"

        local events="$(sed '1, /^\[Events\]/d; /^\[/, $d' "${final}" | tail --lines +2)"
        echo "${events}" >> "${common}"
    done
}

function cut {
    local input="$1"
    local from="$2"
    local to="$3"

    cut_video "${input}" "${from}" "${to}"
    cut_audio "${input}" "${from}" "${to}"
    cut_subtitles "${input}" "${from}" "${to}"
}


function merge_video {
    local input="$1"
    local output="${input/%txt/ts}"

    ffmpeg $COMMON -f concat -safe 0 -i "${input}" -c copy -f mpegts "${output}"

    local stream="$(bc <<< "${#MERGE_STREAMS[@]} / 2")"
    MERGE_INPUT+=(-i "${output}")
    MERGE_STREAMS+=(-map "${stream}:v")
}

function merge_audio {
    local input="$1"
    local output="${input/%txt/flac}"

    if [[ "${input}" =~ \.txt$ ]]; then
        ffmpeg $COMMON -f concat -safe 0 -i "${input}" -c flac "${output}"
    fi

    local stream="$(bc <<< "${#MERGE_STREAMS[@]} / 2")"
    MERGE_INPUT+=(-i "${output}")
    MERGE_STREAMS+=(-map "${stream}:a")
}

function merge_subtitles {
    local output="$1"
    local stream="$(bc <<< "${#MERGE_STREAMS[@]} / 2")"
    MERGE_INPUT+=(-i "${output}")
    MERGE_STREAMS+=(-map "${stream}:s")
}

function merge {
    local output="$1"
    merge_video "${VIDEO_CONCAT}"

    local audio_streams="$(find "${WORKDIR}" -type f -name "audio[0-9][0-9].*")"
    while read -r stream; do
        merge_audio "${stream}"
    done <<< "${audio_streams}"

    local subtitles_streams="$(find "${WORKDIR}" -type f -name "subtitles[0-9][0-9].*")"
    while read -r stream; do
        merge_subtitles "${stream}"
    done <<< "${subtitles_streams}"

    ffmpeg $COMMON "${MERGE_INPUT[@]}" "${MERGE_STREAMS[@]}" -c copy "${output}"
}



# --------------------------------------------------------------------

# 03) 00:00:10.969-00:01:41.309,00:02:01.204-00:23:29.324
INPUT="/mnt/c/Yichang [Ad-Free]/New/03. Your Quarrel Target Has Arrived.mkv"
FROM="00:00:10.969"
TO="00:01:41.309"

# --------------------------------------------------------------------

FROM="$(date --date "1970-01-01T${FROM}Z" +%s.%N)"
TO="$(date --date "1970-01-01T${TO}Z" +%s.%N)"

# INPUT="/mnt/c/AniStar/[AniStar.org] Planting Manual - 01 [720p].mkv"

# --------------------------------------------------------------------









parse_arguments "$@"
for i in $(seq 0 $(( ${#FROM[@]} - 1 ))); do
    echo "FROM: '${FROM[${i}]}'"
    echo "TO: '${TO[${i}]}'"
done







exit 0


rm --force "${WORKDIR}/video"* "${WORKDIR}/audio"* "${WORKDIR}/subtitles"*
cut "$INPUT" "$FROM" "$TO"


# cut_video "$INPUT" "$FROM" "$TO"

# cut_audio "$INPUT" "10.969" "15.015"
# cut_audio "$INPUT" "15.015" "101.226"
# cut_audio "$INPUT" "101.226" "101.309"

# # rm --force "${WORKDIR}/subtitles"*
# cut_subtitles "$INPUT" "10.969" "15.015"
# cut_subtitles "$INPUT" "15.015" "101.226"
# cut_subtitles "$INPUT" "101.226" "101.309"

merge final.mkv
# check_gap final.mkv
# check_gap final.mkv "a:0"
# check_gap final.mkv "a:1"
# check_gap final.mkv "a:2"
# check_gap video.mkv

# info final.mkv

