#!/bin/bash

set -e

EVENT_VARIABLE="$(printenv | grep -i "arr_eventtype=")"

EVENT_TYPE="${EVENT_VARIABLE#*=}"
SERVARR="${EVENT_VARIABLE%%_*}"
TIMESTAMP="$(date "+%Y%m%d_%H%M%S_%N")"

DIRNAME="$(dirname "$0")"
FILENAME="${DIRNAME}/${TIMESTAMP}_${EVENT_TYPE}.json"
JSON="{}"

while read -r line; do
    if [[ "$line" =~ ^${SERVARR}_ ]]; then
        key="${line%%=*}"
        value="${line#*=}"
        JSON="$(echo "${JSON}" | jq -S '.[$key] = $value' \
                --arg key "$key" --arg value "$value")"
    fi
done <<< "$(printenv)"

echo "${JSON}" > "${FILENAME}"
cat "${FILENAME}"
