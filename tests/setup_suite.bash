setup_suite() {
    JSON="{}"

    while read -r line; do
        if [[ "$line" =~ ^BATS_ ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            JSON="$(echo "${JSON}" | jq -S '.[$key] = $value' \
                    --arg key "$key" --arg value "$value")"
        fi
    done <<< "$(printenv)"

    echo "${JSON}" > "${BATS_TEST_DIRNAME}/setup_suite.json"
}
