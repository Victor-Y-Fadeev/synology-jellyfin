#!/bin/bash

set -e


DIR="$(dirname "${BASH_SOURCE[0]}")"
DIR="$(realpath "$DIR")"

TO_KV="${DIR}/json_to_kv.jq"
FROM_KV="${DIR}/json_from_kv.jq"
FROM_PATHS="${DIR}/json_from_paths.jq"

TESTS="$(realpath "${DIR}/../tests/cases")"
SRC="$(realpath "${1:-.}")"


if [[ -f "$SRC" ]]; then
    TMP="$(mktemp -d)"
    unzip "$SRC" -d "$TMP"
    SRC="$TMP"
fi


for test in "${TESTS}"/*/; do
    name="$(basename "$test")"
    file="${SRC}/${name}.json"

    if [[ -f "$file" ]]; then
        cp "$file" "${test}/download/expected.json"

        list="$("$TO_KV" "$file" | sed --posix --regexp-extended 's/^[^\|]*\|//' | sort | uniq)"
        dict="$(echo "$list" | sed --posix --regexp-extended \
            --expression 's/^.*$/\0|\0/' \
            --expression 's/ 0+([0-9]+\/)/ \1/' \
            --expression 's/s[0-9]{2}e[0-9]{2}(-e?[0-9]{2})?/\0 -/' \
            --expression 's/\([0-9]{4}\)\./- \0/' \
            --expression 's/^([^\|]*)\|(.*)$/\2|\1/' \
            --expression '/^([^\|]*)\|\1$/d')"

        "$FROM_PATHS" <<< "$list" > "${test}/delete/expected.json"
        "$FROM_KV" <<< "$dict" > "${test}/rename/expected.json"
    fi
done


rm --force --recursive "$TMP"
