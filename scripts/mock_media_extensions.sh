#!/bin/bash

set -e

EXTENSIONS="mkv|mp4|avi"

if [[ ! -d "$1" ]]; then
    exit
fi

if ! dpkg --status file ffmpeg &>/dev/null; then
    sudo apt --yes install file ffmpeg
fi

TARGET="$(realpath "$1")"
ESCAPE="$(printf '%q' "$EXTENSIONS")"
FILES="$(find "$TARGET" -type f -iregex ".*\.${ESCAPE}$")"

MOCK="$TARGET/tmp.mkv"
ffmpeg -y -lavfi "color=c=black:size=2x2:d=0.1" "$MOCK" &>/dev/null

while read -r name; do
    type="$(file --brief --mime-type "$name")"

    if [[ "$type" =~ ^text ]]; then
        rm --force "$name"
        ln --force "$MOCK" "$name"
    fi
done <<< "$FILES"

rm --force "$MOCK"
