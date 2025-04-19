setup_file() {

    JSON="{}"

    while read -r line; do
        if [[ "$line" =~ ^BATS_ ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            JSON="$(echo "${JSON}" | jq -S '.[$key] = $value' \
                    --arg key "$key" --arg value "$value")"
        fi
    done <<< "$(printenv)"

    echo "${JSON}" > "${BATS_TEST_DIRNAME}/setup_file.json"
}

setup() {
    load 'helpers/bats-support/load'
    load 'helpers/bats-assert/load'
    load 'helpers/bats-file/load'

    JSON="{}"

    while read -r line; do
        if [[ "$line" =~ ^BATS_ ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            JSON="$(echo "${JSON}" | jq -S '.[$key] = $value' \
                    --arg key "$key" --arg value "$value")"
        fi
    done <<< "$(printenv)"

    echo "${JSON}" > "${BATS_TEST_DIRNAME}/setup.json"
}

@test "Hello, world!" {
    run echo "Hello, world!"
    assert_output "Hello, world!"
    BATS_TEST_DESCRIPTION="Hello, world 2!"
}
