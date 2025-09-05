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

# cat "$FRAMES"


# cat "$ENTRIES" | jq --raw-output --stream 'limit(1;select(.[0][0] == "frames" and (.[1].pict_type == "I")) | .[1].pts_time)'
# cat "$ENTRIES" | jq --raw-output --stream 'select(.[0][0] == "frames" and (.[1].pict_type == "I")) | .[1].pts_time'
# cat "$ENTRIES" | jq --raw-output --stream 'fromstream(2|truncate_stream(inputs)) | select(.pict_type=="I") | .pts_time'

# echo '
#   {
#     "results":[
#       {
#         "columns": ["n"],
#         "data": [    
#           {"row": [{"key1": "row1", "key2": "row1"}], "meta": [{"key": "value"}]},
#           {"row": [{"key1": "row2", "key2": "row2"}], "meta": [{"key": "value"}]}
#         ]
#       }
#     ],
#     "errors": []
#   }
# ' | jq --stream '.'
#   fromstream(1|truncate_stream(
#     inputs | select(
#       .[0][0] == "results" and 
#       .[0][2] == "data" and 
#       .[0][4] == "row"
#     ) | del(.[0][0:5])
#   ))'


# cat "$ENTRIES" | jq --raw-output --stream '
#   fromstream(1|truncate_stream(
#     inputs
#     | select(.[0][0]=="frames")
#     | del(.[0][0:2])
#   ))
#   | select(.pict_type=="I")
#   | .pts_time
# '


# ffprobe -loglevel quiet -select_streams v:0 -show_entries packet=pts_time,flags -print_format json "$INPUT" > "packets.json"
# cat "packets.json" | jq --raw-output --stream '
#     fromstream(2|truncate_stream(inputs))
#     | select(.flags | contains("K"))
#     | .pts_time'


# cat "$ENTRIES" | jq --raw-output --stream 'fromstream(1 | truncate_stream(inputs |
#     select(.[0][0] == "frames" and (.[0][2] == "pict_type" or .[0][2] == "pts_time") and .[1] != null)
# ))'
# cat "$ENTRIES" | jq --raw-output --stream '.'


# cat "$ENTRIES" | jq --raw-output --stream '
#     select(.[0][0] == "frames" and (.[0][2] == "pict_type" or .[0][2] == "pts_time") and .[1] != null)
# '

# cat "$ENTRIES" | jq --raw-output --stream 'fromstream(2 | truncate_stream(inputs |
#     select(.[0][0] == "frames" and (.[0][2] == "pict_type" or .[0][2] == "pts_time") and .[1] != null)
#     | del(.[0][0:4])
# ))'

# cat "packets.json" | jq --raw-output --stream '.'


# cat "packets.json" | jq -n --raw-output --stream '
#   fromstream(1|truncate_stream(
#     inputs | select(
#       .[0][0] == "packets"
#     ) | del(.[0][0:1])
#   ))'
cat "$ENTRIES" | jq --null-input --raw-output --stream 'first(fromstream(2 | truncate_stream(inputs)) | select(.pict_type=="I") | .pts_time)'
