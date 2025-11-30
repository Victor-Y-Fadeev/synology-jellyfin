#!/bin/bash
# shellcheck disable=SC2095,SC1091,SC2086
#
# Warning:
#   https://www.shellcheck.net/wiki/SC2095 -- Use ffmpeg -nostdin to prevent ffmpeg from swallowing stdin.
#
# Info:
#   https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing and word splitting.
#   https://www.shellcheck.net/wiki/SC2095 -- ffmpeg may swallow stdin, preventing this loop from working properly.
#
# Style:
#   https://www.shellcheck.net/wiki/SC2248 -- Prefer double quoting even when variables don't contain special characters.

set -e


DELTA="30"
EPSILON="0.001"
COMMON="-y -nostdin -hide_banner -loglevel warning -stats"

WORKDIR="$(mktemp --directory)"
VIDEO_CONCAT="${WORKDIR}/video.txt"
SUBTITLES_OFFSET="0"

MERGE_INPUT=()
MERGE_STREAMS=()


function parse_arguments {
    INPUT="$1"
    FROM=()
    TO=()

    LINK="${WORKDIR}/input.${INPUT##*.}"
    ln --force --symbolic "${INPUT}" "${LINK}"

    MERGED="${WORKDIR}/output.mkv"
    OUTPUT="${INPUT%.*}.merged.mkv"

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
            elif [[ -n "${to}" ]]; then
                TO+=("${to}")
            fi
        fi
    done <<< "$(sed 's/[^0-9.:-]/\n/g' <<< "$@")"

    codec_settings "${LINK}"
    normalize_frames "${LINK}" "FROM"
    normalize_frames "${LINK}" "TO"
}

function codec_settings {
    local input="$1"
    local json="$(ffprobe -loglevel quiet -select_streams v \
                    -show_entries stream=codec_name,has_b_frames,r_frame_rate \
                    -print_format json "${input}")"

    local codec="$(jq --raw-output '.streams[0].codec_name' <<< "${json}")"
    if [[ "${codec}" == "h264" ]]; then
        CODEC="libx264"
        CODEC_PARAMS="-x264-params"
    elif [[ "${codec}" == "hevc" ]]; then
        CODEC="libx265"
        CODEC_PARAMS="-x265-params"
    else
        exit 1
    fi

    B_FRAMES="$(jq --raw-output '.streams[0].has_b_frames' <<< "${json}")"
    FRAME_RATE="($(jq --raw-output '.streams[0].r_frame_rate' <<< "${json}"))"
}

function normalize_frames {
    local input="$1"
    local -n array="$2"

    for i in $(seq 0 $(( ${#array[@]} - 1 ))); do
        local prev="$(prev_frame "${input}" "${array[i]}")"
        if [[ "${prev}" == "0" ]]; then
            array[i]="$(next_intra_frame "${input}" "${prev}")"
            continue
        fi

        local next="$(next_frame "${input}" "${prev}")"
        local diff_prev="$(bc --mathlib <<< "${array[i]} - ${prev}")"
        local diff_next="$(bc --mathlib <<< "${next} - ${array[i]}")"

        if (( $(bc <<< "${diff_prev} < ${diff_next}") )); then
            array[i]="${prev}"
        else
            array[i]="${next}"
        fi
    done
}


function next_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --argjson time "${time}" '
            first(inputs[1] | select(type == "string" and tonumber > $time))'
}

function next_intra_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --argjson time "${time}" '
            first(inputs[1] | select(type == "string" and tonumber >= $time))'
}

function next_predicted_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time,pict_type -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --argjson time "${time}" '
            first(foreach (inputs | flatten | select(length == 4 and (.[2] == "pts_time" or .[2] == "pict_type"))
                ) as $item ([[], []]; [.[1], $item])
                    | select(.[0][1] == .[1][1] and (.[1][3] == "I" or .[1][3] == "P"))
                    | .[0][3] | select(tonumber >= $time))'
}

function prev_frame {
    local input="$1"
    local time="$2"

    local epsilon="${3:-$EPSILON}"
    local start="0$(bc <<< "if (${time} < ${epsilon}) 0 else ${time} - ${epsilon}")"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -print_format json \
            -read_intervals "${start}%" "${input}" \
        | jq --null-input --raw-output --stream --argjson time "${time}" '
            first(foreach (inputs[1] | select(type == "string") | tonumber) as $item
                    ([0, 0]; [.[1], $item]) | select(.[1] >= $time) | .[0])'
}

function prev_intra_frame {
    local input="$1"
    local time="$2"

    local delta="${3:-$DELTA}"
    local start="0$(bc <<< "if (${time} < ${delta}) 0 else ${time} - ${delta}")"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${start}%${time}" "${input}" \
        | jq --raw-output '.frames | map(.pts_time | tonumber) | max // 0'
}

function prev_predicted_frame {
    local input="$1"
    local time="$2"

    local epsilon="${3:-$EPSILON}"
    local start="0$(bc <<< "if (${time} < ${epsilon}) 0 else ${time} - ${epsilon}")"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time,pict_type -print_format json \
            -read_intervals "${start}%${time}" "${input}" \
        | jq --raw-output '.frames | map(select(.pict_type == "I" or .pict_type == "P") | .pts_time | tonumber) | max // 0'
}


function count_frames {
    local input="$1"
    local from="$2"
    local to="$3"

    local frames="$(bc --mathlib <<< "(${to} - ${from}) * (${FRAME_RATE})")"
    frames="$(bc <<< "scale=0; (${frames} + 0.5) / 1")"
    echo "${frames}"
}

function cut_video_recoding {
    local input="$1"
    local from="$2"
    local to="$3"

    local config="${WORKDIR}/video-${from}-${to}.txt"
    echo "file '${input}'" > "${config}"

    local prev="$(prev_intra_frame "${input}" "${from}")"
    echo "inpoint ${prev}" >> "${config}"
    local filter="trim=start=0$(bc <<< "${from} - ${prev}")"

    local params="scenecut=0"
    if [[ -n "${to}" ]]; then
        local next="$(next_intra_frame "${input}" "${to}")"
        if [[ -n "${next}" ]]; then
            echo "outpoint ${next}" >> "${config}"
        fi

        filter="${filter}:end=0$(bc <<< "${to} - ${prev}")"
        keyint="$(( $(count_frames "${input}" "${from}" "${to}") - 1 ))"
        params="keyint=${keyint}:min-keyint=${keyint}:${params}"
    fi

    local output="${WORKDIR}/video-${from}-${to}.ts"
    ffmpeg $COMMON -f concat -safe 0 -i "${config}" \
        -map v -vf "${filter},setpts=PTS-STARTPTS" \
        -c $CODEC $CODEC_PARAMS "${params}" \
        -crf 1 -bf "${B_FRAMES}" -f mpegts "${output}"

    echo "file '${output}'" >> "${VIDEO_CONCAT}"
}

function cut_video_copy {
    local input="$1"
    local from="$2"
    local to="$3"

    local config="${WORKDIR}/video-${from}-${to}.txt"
    echo "file '${input}'" > "${config}"
    echo "inpoint ${from}" >> "${config}"

    local frames=""
    if [[ -n "${to}" ]]; then
        frames="-frames $(count_frames "${input}" "${from}" "${to}")"
    fi

    local output="${WORKDIR}/video-${from}-${to}.ts"
    ffmpeg $COMMON -f concat -safe 0 -i "${config}" $frames \
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
    if (( $(bc <<< "${start} < ${end}") )); then
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
    while read -r stream && [[ -n "${stream}" ]]; do
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

function cut_subtitles_srt_reindex {
    local index=1
    local expect=1

    while read -r line; do
        if [[ "${line}" == "${expect}" ]]; then
            echo "${index}"
            (( ++index ))
            (( ++expect ))
        elif [[ "${line}" == "1" ]]; then
            echo "${index}"
            (( ++index ))
            expect=2
        else
            echo "${line}"
        fi
    done <<< "$(cat)"
}

function cut_subtitles_srt {
    local input="$1"
    local stream="$2"
    local from="$3"
    local to="$4"

    local segment="-ss ${from}"
    if [[ -n "${to}" ]]; then
        segment="${segment} -to ${to}"
    fi

    local common="${WORKDIR}/subtitles$(printf '%02d' "${stream}").srt"
    local cut="${common%.*}-${from}-${to}.srt"
    local final="${cut%.*}-offset.srt"

    ffmpeg $COMMON -i "${input}" $segment -map "s:${stream}" -c copy -f srt "${cut}"
    ffmpeg $COMMON -itsoffset "${SUBTITLES_OFFSET}" -i "${cut}" -map s -c copy -f srt "${final}"

    if [[ ! -f "${common}" ]]; then
        touch "${common}"
    fi

    local subtitles="$(cat "${common}" "${final}" | cut_subtitles_srt_reindex)"
    echo "${subtitles}" > "${common}"
}

function cut_subtitles_ass_common {
    local input="$1"
    local stream="$2"

    local output="${WORKDIR}/subtitles$(printf '%02d' "${stream}").ass"
    echo "${output}"

    if [[ ! -f "${output}" ]]; then
        ffmpeg $COMMON -i "${input}" -map "s:${stream}" -c copy -f ass "${output}"

        local header="$(sed            '/^\[Events\]/, $d'         "${output}")"
        local format="$(sed         '1, /^\[Events\]/d; /^\[/, $d' "${output}" | head --lines 1)"
        local footer="$(sed --quiet '1, /^\[Events\]/d; /^\[/, $p' "${output}")"

        echo "${header}" > "${output}"
        echo "${footer}" >> "${output}"

        echo "[Events]" >> "${output}"
        echo "${format}" >> "${output}"
    fi
}

function cut_subtitles_ass {
    local input="$1"
    local stream="$2"
    local from="$3"
    local to="$4"

    local segment="-ss ${from}"
    if [[ -n "${to}" ]]; then
        segment="${segment} -to ${to}"
    fi

    local common="$(cut_subtitles_ass_common "${input}" "${stream}")"
    local cut="${common%.*}-${from}-${to}.ass"
    local final="${cut%.*}-offset.ass"

    ffmpeg $COMMON -i "${input}" $segment -map "s:${stream}" -c copy -f ass "${cut}"
    local offset="$(bc <<< "scale=2; (${SUBTITLES_OFFSET} + 0.005) / 1")"
    ffmpeg $COMMON -itsoffset "${offset}" -i "${cut}" -map s -c copy -f ass "${final}"

    local events="$(sed '1, /^\[Events\]/d; /^\[/, $d' "${final}" | tail --lines +2)"
    echo "${events}" >> "${common}"
}

function cut_subtitles {
    local input="$1"
    local from="$2"
    local to="$3"

    local streams="$(ffprobe -loglevel quiet -select_streams s -show_entries stream=codec_name \
                        -print_format json "${input}" | jq --raw-output '.streams[] | .codec_name')"

    local i=0
    while read -r stream && [[ -n "${stream}" ]]; do
        if [[ "${stream}" == "ass" ]]; then
            cut_subtitles_ass "${input}" "${i}" "${from}" "${to}"
        elif [[ "${stream}" == "subrip" ]]; then
            cut_subtitles_srt "${input}" "${i}" "${from}" "${to}"
        fi

        (( ++i ))
    done <<< "${streams}"

    if [[ -n "${to}" ]]; then
        SUBTITLES_OFFSET="$(bc <<< "${SUBTITLES_OFFSET} + ${to} - ${from}")"
    fi
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

    local audio_streams="$(find "${WORKDIR}" -type f -name "audio[0-9][0-9].*" | sort)"
    while read -r stream && [[ -n "${stream}" ]]; do
        merge_audio "${stream}"
    done <<< "${audio_streams}"

    local subtitles_streams="$(find "${WORKDIR}" -type f -name "subtitles[0-9][0-9].*" | sort)"
    while read -r stream && [[ -n "${stream}" ]]; do
        merge_subtitles "${stream}"
    done <<< "${subtitles_streams}"

    ffmpeg $COMMON "${MERGE_INPUT[@]}" "${MERGE_STREAMS[@]}" -c copy "${output}"
}


function copy_metadata {
    local input="$1"
    local output="$2"
    local args=()

    local metadata="$(mkvmerge -J "${input}")"
    local length="$(jq '.tracks | length' <<< "${metadata}")"

    for i in $(seq 1 "${length}"); do
        local properties="$(jq --argjson idx "${i}" '.tracks[$idx - 1].properties' <<< "${metadata}")"
        args+=(--edit "track:${i}")

        local name="$(jq --raw-output '.track_name' <<< "${properties}")"
        if [[ "$name" != "null" ]]; then
            args+=(--set "name=${name}")
        fi

        local language="$(jq --raw-output '.language' <<< "${properties}")"
        if [[ "$language" != "und" ]]; then
            args+=(--set "language=${language}")
        fi

        local default="$(jq --raw-output 'if .default_track then 1 else 0 end' <<< "${properties}")"
        args+=(--set "flag-default=${default}")

        local forced="$(jq --raw-output 'if .forced_track then 1 else 0 end' <<< "${properties}")"
        args+=(--set "flag-forced=${forced}")
    done

    mkvpropedit "${output}" "${args[@]}" --tags all:
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"

    for IDX in $(seq 0 $(( ${#FROM[@]} - 1 ))); do
        cut "${LINK}" "${FROM[IDX]}" "${TO[IDX]}"
    done

    merge "${MERGED}"
    copy_metadata "${LINK}" "${MERGED}"

    mkvmerge --output "${OUTPUT}" "${MERGED}"
    rm --force --recursive "${WORKDIR}"
fi
