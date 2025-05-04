#!/bin/bash

set -e


DIR="$(dirname "${BASH_SOURCE[0]}")"
ROOT="$(realpath "${DIR}/..")"

DOCKER_COMPOSE="${ROOT}/compose.yaml"
SETTINGS_DIR="${ROOT}/settings"
SETTINGS_FILE="${SETTINGS_DIR}/settings.md"


if ! command -v yq &>/dev/null; then
    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
fi

rm --force "$SETTINGS_FILE"

for i in $(yq --output-format tsv '.services | keys' "$DOCKER_COMPOSE"); do
    markdown="${SETTINGS_DIR}/${i}.md"

    if [[ -f "$markdown" ]]; then
        cat "$markdown" >> "$SETTINGS_FILE"
        echo "" >> "$SETTINGS_FILE"
    fi
done
