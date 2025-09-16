#!/bin/bash

set -e

DELTA="30"
EPSILON="0.000001"
GAP="0.002"

COMMON="-y -nostdin -hide_banner -loglevel warning -stats"

WORKDIR="$(realpath .)"
# WORKDIR="$(mktemp --directory)"
VIDEO_CONCAT="${WORKDIR}/video.txt"

MERGE_INPUT=()
MERGE_STREAMS=()

# INPUT="$(realpath "$1")"

# FROM="$(date --date "1970-01-01T${2}Z" +%s.%N)"
# TO="$(date --date "1970-01-01T${3}Z" +%s.%N)"


function info {
    ffprobe -loglevel quiet -select_streams "${2:-v}" -show_streams -print_format json "$1"
}

function check_gap {
    local input="$1"
    local stream="${2:-v}"
    local gap="${3:-$GAP}"

    ffprobe -loglevel quiet -select_streams "${stream}" -show_entries frame=pts_time -print_format json "${input}" \
        | jq --arg gap "${gap}" '
            def step($prev; $next):
                { prev: $prev, next: $next, diff: (if $prev | type == "object" then
                    ($next.diff - $prev.diff) * 1000 | round / 1000
                else
                    ($next - $prev) * 1000 | round / 1000
                end )};

            def diff:
                reduce .[1:][] as $item ({ prev: .[0], out: [] };
                    .out += [step(.prev; $item)]
                    | .prev = $item
                ) | .out;

            .frames | map(.pts_time | tonumber) | diff | diff
                    | map(select(.diff > ($gap | tonumber)) | if .prev.diff > 0 then
                            { time: .next.prev, duration: .next.diff, gap: .diff }
                        else
                            { time: .prev.prev, duration: .prev.diff, gap: .diff }
                        end)'
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
    # time="0$(bc <<< "${time} + ${EPSILON}")"

    ffprobe -loglevel quiet -select_streams v -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${start}%${time}" "${input}" \
        | jq --raw-output --arg time "${time}" '.frames | map(.pts_time | tonumber) | max'
}

function prev_predicted_frame {
    local input="$1"
    local time="$2"

    local delta="${3:-$DELTA}"
    local start="0$(bc <<< "if (${time} < ${delta}) 0 else ${time} - ${delta}")"
    # time="0$(bc <<< "${time} + ${EPSILON}")"

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

function merge {
    local output="$1"
    merge_video "${VIDEO_CONCAT}"

    local audio_streams="$(find "${WORKDIR}" -type f -name "audio[0-9][0-9].*")"
    while read -r stream; do
        merge_audio "${stream}"
    done <<< "${audio_streams}"

    # local subtitles_streams="$(find "${WORKDIR}" -type f -name "subtitles[0-9][0-9].*")"
    # while read -r stream; do
    #     merge_subtitles "${stream}"
    # done <<< "${subtitles_streams}"

    ffmpeg $COMMON "${MERGE_INPUT[@]}" "${MERGE_STREAMS[@]}" -c copy "${output}"
}



# TIME="10.600"

# next_intra_frame "$INPUT" "$TIME"
# prev_intra_frame "$INPUT" "$TIME"

# --------------------------------------------------------------------

# 03) 00:00:10.969-00:01:41.309,00:02:01.204-00:23:29.324
INPUT="/mnt/c/Yichang [Ad-Free]/New/03. Your Quarrel Target Has Arrived.mkv"
FROM="00:00:10.969"
TO="00:01:41.309"

# --------------------------------------------------------------------


FROM="$(date --date "1970-01-01T${FROM}Z" +%s.%N)"
TO="$(date --date "1970-01-01T${TO}Z" +%s.%N)"



# INPUT="/mnt/c/AniStar/[AniStar.org] Planting Manual - 01 [720p].mkv"

rm --force "${WORKDIR}/video"* "${WORKDIR}/audio"* "${WORKDIR}/subtitles"*
# cut_video "$INPUT" "$FROM" "$TO"
# # # merge_video
# # # echo "$WORKDIR"
# # # check_gap "${WORKDIR}/video.mkv"

# cut_audio "$INPUT" "10.969" "15.015"
# cut_audio "$INPUT" "15.015" "101.226"
# cut_audio "$INPUT" "101.226" "101.309"


TEST="00:23:28.073"
TEST="$(date --date "1970-01-01T${TEST}Z" +%s.%N)"
cut_video "$INPUT" "$TEST"
cut_audio "$INPUT" "$TEST"


merge final.mkv
check_gap final.mkv
check_gap final.mkv "a:0"
# check_gap final.mkv "a:1"
# check_gap final.mkv "a:2"
# check_gap video.mkv


# ffmpeg $COMMON -f concat -safe 0 -i "video.txt" -c copy -f mpegts "video.ts"
# check_gap video.ts
# ffmpeg $COMMON -i video.ts -i audio00.aac -map 0:v -map 1:a -c copy video_audio.mkv
# check_gap video_audio.mkv


# check_gap "audio00.aac" "a"
# check_gap "audio01.ac3" "a"
# check_gap "audio02.aac" "a"


# ls -1 -f "${WORKDIR}"/audio[0-9][0-9]..*
# for i in "${WORKDIR}"/audio[0-9][0-9].*; do
# for i in $(find "${WORKDIR}" -type f -name "audio[0-9][0-9].*"); do
#     echo "'$(realpath "${i}")'"
# done

exit 0

# ffmpeg -y -hide_banner -loglevel warning -stats \
#   -i "$INPUT" -map 0:a? -map 0:s? -c copy "source.mkv"

# echo "file 'source.mkv'" > "audio.txt"
# echo "inpoint $FROM" >> "audio.txt"
# echo "outpoint $TO" >> "audio.txt"


# ffmpeg -y -hide_banner -loglevel warning -stats \
#     -f concat -safe 0 -i "audio.txt" -map 0 -c copy "audio.mkv"

# INPUT="/mnt/c/AniStar/[AniStar.org] Planting Manual - 01 [720p].mkv"
# ffprobe -loglevel quiet -select_streams a -show_entries stream=codec_name -print_format json "$INPUT" \
#     | jq --raw-output '.streams[] | .codec_name'
# exit 0

# --------------------------------------------------------------------

# FLAC


ffmpeg $COMMON -i "$INPUT" -ss  10.969 -to  15.015 -map a:0 -c pcm_s16le w1.wav
ffmpeg $COMMON -i "$INPUT" -ss  15.015 -to 101.226 -map a:0 -c pcm_s16le w2.wav
ffmpeg $COMMON -i "$INPUT" -ss 101.226 -to 101.309 -map a:0 -c pcm_s16le w3.wav

echo "file 'w1.wav'" >  "wav.txt"
echo "file 'w2.wav'" >> "wav.txt"
echo "file 'w3.wav'" >> "wav.txt"

ffmpeg $COMMON -f concat -safe 0 -i wav.txt -c flac a0.mka
check_gap a0.mka a

# ffmpeg -y -hide_banner -loglevel warning -stats -i "$INPUT" -ss  10.969 -to  15.015 -map 0:a:0 -c copy a0_1.mka
# ffmpeg -y -hide_banner -loglevel warning -stats -i a0_1.mka -c copy -f flac a0_1.flac
# ffmpeg -y -hide_banner -loglevel warning -stats -i "$INPUT" -ss  15.015 -to 101.226 -map 0:a:0 -c copy a0_2.mka
# ffmpeg -y -hide_banner -loglevel warning -stats -i a0_2.mka -c copy -f flac a0_2.flac
# ffmpeg -y -hide_banner -loglevel warning -stats -i "$INPUT" -ss 101.226 -to 101.309 -map 0:a:0 -c copy a0_3.mka
# ffmpeg -y -hide_banner -loglevel warning -stats -i a0_3.mka -c copy -f flac a0_3.flac

# echo "file 'a0_1.flac'" > "a0.txt"
# echo "file 'a0_2.flac'" >> "a0.txt"
# echo "file 'a0_3.flac'" >> "a0.txt"

# ffmpeg -y -hide_banner -loglevel warning -stats -f concat -safe 0 -i "a0.txt" -c copy "a0.mka"
# check_gap a0.mka
exit 0

# --------------------------------------------------------------------

# AC-3 | ASS
type="adts" # "ass"

ffmpeg $COMMON -i "$INPUT" -ss  10.969 -to  15.015 -map 0:a:0 -c copy -f "$type" "a0_1.$type"
ffmpeg $COMMON -i "$INPUT" -ss  15.015 -to 101.226 -map 0:a:0 -c copy -f "$type" "a0_2.$type"
ffmpeg $COMMON -i "$INPUT" -ss 101.226 -to 101.309 -map 0:a:0 -c copy -f "$type" "a0_3.$type"

cat "a0_1.$type" "a0_2.$type" "a0_3.$type" > "a0_cat.$type"
ffmpeg $COMMON -i "a0_cat.$type" -c copy "a0.mka"

# echo "file 'a0_1.$type'" > "a0.txt"
# echo "file 'a0_2.$type'" >> "a0.txt"
# echo "file 'a0_3.$type'" >> "a0.txt"

# ffmpeg $COMMON -f concat -safe 0 -i "a0.txt" -c copy "a0.mka"
# ffmpeg $COMMON -i "concat:a0_1.$type|a0_2.$type|a0_3.$type" -c copy "a0.mka"

check_gap a0.mka

exit 0


# --------------------------------------------------------------------

# check_gap audio-file-*.mkv
# check_gap audio-concat-*.mkv
# check_gap audio-cut-*.mkv

SR=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 a0.mka)
ffprobe -v error -select_streams a:0 -show_frames -show_entries frame=nb_samples -of csv=p=0 a0.mka \
  | awk -v sr="$SR" '{sum+=$1} END{printf "%.6f\n", sum/sr}'


exit 0

# --------------------------------------------------------------------

ffmpeg -y -hide_banner -loglevel warning -stats \
    -i "$INPUT" -ss "10.969" -to "15.015" -map 0:a? -map 0:s? -c copy "audio-10.969-15.015.mkv"

ffmpeg -y -hide_banner -loglevel warning -stats \
    -i "$INPUT" -ss "15.015" -to "101.226" -map 0:a? -map 0:s? -c copy "audio-15.015-101.226.mkv"

ffmpeg -y -hide_banner -loglevel warning -stats \
    -i "$INPUT" -ss "101.226" -to "101.309" -map 0:a? -map 0:s? -c copy "audio-101.226-101.309.mkv"

echo "file 'audio-10.969-15.015.mkv'" > "audio.txt"
echo "file 'audio-15.015-101.226.mkv'" >> "audio.txt"
echo "file 'audio-101.226-101.309.mkv'" >> "audio.txt"

ffmpeg -y -hide_banner -loglevel warning -stats \
    -f concat -safe 0 -i "audio.txt" -map 0 -c copy "audio-file-10.969-15.015-101.226-101.309.mkv"

ffmpeg -y -hide_banner -loglevel warning -stats \
    -i "concat:audio-10.969-15.015.mkv|audio-15.015-101.226.mkv|audio-101.226-101.309.mkv" \
    -map 0 -c copy "audio-concat-10.969-15.015-101.226-101.309.mkv"

ffmpeg -y -hide_banner -loglevel warning -stats \
    -i "$INPUT" -ss "10.969" -to "101.309" -map 0:a? -map 0:s? -c copy "audio-cut-10.969-101.309.mkv"

exit 0

# --------------------------------------------------------------------

# cat > audio_subs.txt <<EOF
# file '$INPUT'
# inpoint 10.969000000
# outpoint 15.015000
# file '$INPUT'
# inpoint 15.015000
# outpoint 101.226000
# file '$INPUT'
# inpoint 101.226000
# outpoint 101.309000000
# EOF

# ffmpeg -y -hide_banner -loglevel warning -stats \
#   -f concat -safe 0 -i audio_subs.txt \
#   -map 0 -map -0:v -map -0:t -dn \
#   -c copy \
#   -fflags +genpts -avoid_negative_ts make_zero -muxpreload 0 -muxdelay 0 \
#   audio_subs.mkv

# ffmpeg -y -hide_banner -loglevel warning -stats \
#     -i "$INPUT" -ss "$FROM" -to "$TO" -map 0:a? -map 0:s? -c copy "audio.mkv"


# ffmpeg -y -hide_banner -loglevel warning -stats \
#   -i "video.mkv" -i "audio.mkv" \
#   -map 0:v -map 1:a? -map 1:s? -c copy "final.mkv"






TEST="00:23:28.073"
TEST="$(date --date "1970-01-01T${TEST}Z" +%s.%N)"

# echo "TEST: ${TEST}"
# echo "NEXT: $(next_intra_frame "$INPUT" "$TEST")"
# echo "PREV: $(prev_intra_frame "$INPUT" "$TEST")"

# prev_predicted_frame "$INPUT" ""

# R="100500"
# L="x"
# if [[ -z "$R" || -n "$L" ]] && (( $(bc <<< "${TEST} < ${R}") )); then
#     echo "R="recoding""
#     echo "$(bc <<< "${TEST} < ${R}")"
# fi

# next_intra_frame "$INPUT" "0.0"



# info "$INPUT"
BEFORE="$(prev_intra_frame "$INPUT" "$FROM")"
NEXT="$(next_intra_frame "$INPUT" "$FROM")"
PREV="$(prev_intra_frame "$INPUT" "$TO")"
AFTER="$(next_intra_frame "$INPUT" "$TO")"

echo "[${BEFORE}, ${NEXT}) - All-I recoding"
echo "[${FROM}, ${NEXT}) - Cut"
echo "[${NEXT}, ${PREV}) - Copy"
echo "[${PREV}, ${TO}) - All-I recoding"



cut_video_recoding "$INPUT" "$FROM" "$TO"
echo "$WORKDIR"




# P="$(prev_predicted_frame "$INPUT" "$TO")"
# echo "P: ${P}"
prev_predicted_frame "$INPUT" "$TO"
next_intra_frame "$INPUT" "$NEXT"


P_NEXT="00:01:40.141"
P_NEXT="$(date --date "1970-01-01T${P_NEXT}Z" +%s.%N)"
echo "P_NEXT: ${P_NEXT}"
next_frame "$INPUT" "$PREV"
# prev_intra_frame "$INPUT" "$FROM"


# ffmpeg -y -hide_banner -i "$INPUT" -ss "$FROM" -to "$NEXT" -map 0:v -c:v libx264 -crf 1 -g 1 -x264-params repeat-headers=1 -bsf:v h264_mp4toannexb -f mpegts "A.ts"
# ffmpeg -y -hide_banner -i "$INPUT" -ss "$NEXT" -to "$PREV" -map 0:v -c:v copy -fflags +genpts -avoid_negative_ts make_zero -bsf:v h264_mp4toannexb -f mpegts "B.ts"
# ffmpeg -y -hide_banner -i "$INPUT" -ss "$PREV" -to "$TO"   -map 0:v -c:v libx264 -crf 1 -g 1 -x264-params repeat-headers=1 -bsf:v h264_mp4toannexb -f mpegts "C.ts"

# cat A.ts B.ts C.ts > V.ts

# ffmpeg -y -hide_banner -i V.ts -map 0:v -c:v copy V.mkv

# check_gap "V.mkv"

# cat > center.txt <<EOF
# file '$INPUT'
# inpoint $NEXT
# outpoint $PREV
# EOF

# ffmpeg -y -hide_banner -f concat -safe 0 -i center.txt -map 0:v -c:v copy -f mpegts B.ts

# --------------------------------------------------------------------
exit 0
# --------------------------------------------------------------------


cat > left.txt <<EOF
file '$INPUT'
inpoint $BEFORE
outpoint $NEXT
EOF

# ffmpeg -y -hide_banner -loglevel warning -stats -f concat -safe 0 -i left.txt -map 0:v -c:v libx264 -crf 1 -g 1 -f mpegts A.ts

FPS="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$INPUT")"
echo "FPS: ${FPS}"


START_REL="0$(bc <<< "$FROM - $BEFORE")"
END_REL="0$(bc <<< "$NEXT - $BEFORE")"
echo "START_REL: ${START_REL}"
echo "END_REL: ${END_REL}"
echo "EXPECTED DURATION: 0$(bc <<< "$NEXT - $FROM")"

ffmpeg -y -hide_banner -loglevel warning -stats -f concat -safe 0 -i left.txt \
  -map 0:v \
  -vf "trim=start=${START_REL}:end=${END_REL},setpts=PTS-STARTPTS" \
  -c:v libx264 -crf 1 -g 1 -f mpegts A.ts

exit 0

P_NEXT="00:01:40.141"
P_NEXT="$(date --date "1970-01-01T${P_NEXT}Z" +%s.%N)"


cat > center.txt <<EOF
file '$INPUT'
inpoint $NEXT
outpoint $P_NEXT
EOF

echo "EXPECTED DURATION: 0$(bc <<< "$P_NEXT - $NEXT")"
ffmpeg -y -hide_banner -loglevel warning -stats -f concat -safe 0 -i center.txt -map 0:v -c:v copy \
 -f mpegts B.ts

cat > right.txt <<EOF
file '$INPUT'
inpoint $PREV
outpoint $AFTER
EOF

START_REL="0$(bc <<< "$P_NEXT - $PREV")"
END_REL="0$(bc <<< "$TO - $PREV")"
echo "START_REL: ${START_REL}"
echo "END_REL: ${END_REL}"


ffmpeg -y -hide_banner -loglevel warning -stats -f concat -safe 0 -i right.txt \
  -map 0:v \
  -vf "trim=start=${START_REL}:end=${END_REL}" \
  -c:v libx264 -crf 1 -g 1 -f mpegts C.ts


echo "FULL DURATION: 0$(bc <<< "$TO - $FROM")"

cat > merge.txt <<EOF
file A.ts
file B.ts
file C.ts
EOF

ffmpeg -y -hide_banner -loglevel warning -stats -f concat -safe 0 -i merge.txt -map 0:v -c:v copy V.mkv

check_gap "V.mkv"


# ffprobe -v error -select_streams v:0 -show_entries frame=pts_time,pict_type -of csv=p=0 V.mkv \
#   | awk 'NR>1{d=$1-p; if(d>0.06) printf "GAP %.3f at %s -> %s\n", d, p, $1; } {p=$1}'


# echo '[89.172000, 89.213000, 89.256000, 89.298000]' |  jq --exit-status '
#     def step($prev; $next):
#         { prev: $prev, next: $next, diff: (if $prev | type == "object" then
#             ($next.diff - $prev.diff) * 1000 | round / 1000
#         else
#             ($next - $prev) * 1000 | round / 1000
#         end )};

#     def diff:
#         reduce .[1:][] as $item ({ prev: .[0], out: [] };
#             .out += [step(.prev; $item)]
#             | .prev = $item
#         ) | .out;

# diff | diff | map(select(.diff > 0.0015) | { time: .next.prev, duration: .next.diff, gap: .diff })'

# echo "'$?'"

# check_gap "V.mkv"

# echo "'$?'"



# ffmpeg -y -hide_banner -i "concat:A.ts|B.ts" \
#   -map 0:v:0 -c:v copy \
#   -bsf:v h264_metadata=aud=insert \
#   -fflags +genpts -avoid_negative_ts make_zero \
#   V.mkv





# --------------------------------------------------------------------

# echo "file '[${FROM}, ${NEXT}).mkv'" > list.txt
# echo "file '[${NEXT}, ${PREV}).mkv'" >> list.txt
# echo "file '[${PREV}, ${TO}).mkv'" >> list.txt
# ffmpeg -y -hide_banner -f concat -safe 0 -i list.txt -c copy "[${FROM}, ${TO}).mkv"


# --------------------------------------------------------------------

# 15.015000-100.1
# 00:00:15.015000-00:01:40.100000

# mkvmerge -o B.mkv --no-global-tags --no-chapters --no-attachments \
#   --split parts:00:00:15.015000-00:01:40.100000 "$INPUT"



# ffprobe -v error -select_streams v:0 \
#   -show_entries stream=start_time,time_base -of json B.mkv
# ожидание: "start_time": "0.000000"


# ffmpeg -y -hide_banner -f concat -safe 0 -i list.txt -c copy "[${FROM}, ${TO}).mkv"
# info "$INPUT"

# ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time,pkt_dts_time,pict_type -print_format json "$INPUT" > "frames.json"

# ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time,pkt_dts_time,pict_type -print_format json "[${FROM}, ${NEXT}).mkv" > "frames_2.json"

# ffprobe -loglevel quiet -select_streams v:0 -show_frames -print_format json "$INPUT" > "frames_all.json"
# info "$INPUT" > info.txt

# cat > center.txt <<EOF
# file '$INPUT'
# inpoint $NEXT
# outpoint $PREV
# EOF

# ffmpeg -y -hide_banner -f concat -safe 0 -i center.txt \
#   -map 0:v -map 0:a? -map 0:s? -map -0:t -map_metadata -1 -map_chapters -1 -dn \
#   -c copy -fflags +genpts -avoid_negative_ts make_zero \
#   B.mkv

# ffmpeg -y -hide_banner -f concat -safe 0 -i list.txt -c copy "[${FROM}, ${TO}).mkv"


# --------------------------------------------------------------------

# cat > left.txt <<EOF
# file '$INPUT'
# inpoint $FROM
# outpoint $NEXT
# EOF

# ffmpeg -y -hide_banner -f concat -safe 0 -i left.txt \
#   -map 0:v -map 0:a? -map 0:s? -map -0:t -map_metadata -1 -map_chapters -1 -dn \
#   -c copy -fflags +genpts -avoid_negative_ts make_zero \
#   A.mkv


# cat > center.txt <<EOF
# file '$INPUT'
# inpoint $NEXT
# outpoint $PREV
# EOF

# ffmpeg -y -hide_banner -f concat -safe 0 -i center.txt \
#   -map 0:v -map 0:a? -map 0:s? -map -0:t -map_metadata -1 -map_chapters -1 -dn \
#   -c copy -fflags +genpts -avoid_negative_ts make_zero \
#   B.mkv


# echo "file 'A.mkv'" > merge.txt
# echo "file 'B.mkv'" >> merge.txt

# ffmpeg -y -hide_banner -f concat -safe 0 -i merge.txt -c copy "A_B.mkv"

# info A.mkv
# info B.mkv

# --------------------------------------------------------------------

# A -> TS
# ffmpeg -y -hide_banner -i A.mkv \
#   -map 0:v -map 0:a? -c:v copy -c:a copy \
#   -bsf:v h264_mp4toannexb -f mpegts A.ts

# # B -> TS
# ffmpeg -y -hide_banner -i B.mkv \
#   -map 0:v -map 0:a? -c:v copy -c:a copy \
#   -bsf:v h264_mp4toannexb -f mpegts B.ts

# # байтовая склейка
# cat A.ts B.ts > AB.ts

# # ремультиплекс обратно в MKV
# ffmpeg -y -hide_banner -i AB.ts \
#   -c copy -bsf:v h264_metadata=aud=insert -fflags +genpts -avoid_negative_ts make_zero \
#   "A_B.mkv"
