#!/bin/bash

set -e

DELTA="30"

# INPUT="$(realpath "$1")"

# FROM="$(date --date "1970-01-01T${2}Z" +%s.%N)"
# TO="$(date --date "1970-01-01T${3}Z" +%s.%N)"


function next_key_frame {
    local input="$1"
    local time="$2"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${time}%" "${input}" \
        | jq --null-input --raw-output --stream --arg time "${time}" '
            first(inputs[1] | select(type == "string" and tonumber >= ($time | tonumber)))'
}

function prev_key_frame {
    local input="$1"
    local time="$2"

    local delta="${3:-$DELTA}"
    local start="0$(bc <<< "if (${time} < ${delta}) 0 else ${time} - ${delta}")"

    ffprobe -loglevel quiet -select_streams v:0 -show_entries frame=pts_time -skip_frame nokey -print_format json \
            -read_intervals "${start}%${time}" "${input}" \
        | jq --raw-output --arg time "${time}" '.frames | map(.pts_time | tonumber) | max'
}

function info {
    ffprobe -loglevel quiet -select_streams v:0 -show_streams -print_format json "$1"
}


# TIME="10.600"

# next_key_frame "$INPUT" "$TIME"
# prev_key_frame "$INPUT" "$TIME"

# --------------------------------------------------------------------

# 03) 00:00:10.969-00:01:41.309,00:02:01.204-00:23:29.324
INPUT="/mnt/c/Yichang [Ad-Free]/New/03. Your Quarrel Target Has Arrived.mkv"
FROM="00:00:10.969"
TO="00:01:41.309"

# --------------------------------------------------------------------


FROM="$(date --date "1970-01-01T${FROM}Z" +%s.%N)"
TO="$(date --date "1970-01-01T${TO}Z" +%s.%N)"

# info "$INPUT"
NEXT="$(next_key_frame "$INPUT" "$FROM")"
PREV="$(prev_key_frame "$INPUT" "$TO")"

echo "[${FROM}, ${NEXT}) - All-I recoding"
echo "[${NEXT}, ${TO}) - Copy"
echo "[${PREV}, ${TO}) - All-I recoding"
# prev_key_frame "$INPUT" "$FROM"


# ffmpeg -y -hide_banner -i "$INPUT" -ss "$FROM" -to "$NEXT" -map 0:v -c:v libx264 -crf 1 -g 1 -x264-params repeat-headers=1 -bsf:v h264_mp4toannexb -f mpegts "A.ts"
# ffmpeg -y -hide_banner -i "$INPUT" -ss "$NEXT" -to "$PREV" -map 0:v -c:v copy -fflags +genpts -avoid_negative_ts make_zero -bsf:v h264_mp4toannexb -f mpegts "B.ts"
# ffmpeg -y -hide_banner -i "$INPUT" -ss "$PREV" -to "$TO"   -map 0:v -c:v libx264 -crf 1 -g 1 -x264-params repeat-headers=1 -bsf:v h264_mp4toannexb -f mpegts "C.ts"

# cat A.ts B.ts C.ts > V.ts

# ffmpeg -y -hide_banner -i V.ts -map 0:v -c:v copy V.mkv

cat > center.txt <<EOF
file '$INPUT'
inpoint $NEXT
outpoint $PREV
EOF

ffmpeg -y -hide_banner -f concat -safe 0 -i center.txt -map 0:v -c:v copy -f mpegts B.ts


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
