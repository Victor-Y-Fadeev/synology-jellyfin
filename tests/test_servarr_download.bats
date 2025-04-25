setup_file() {
    ROOT="$(dirname "${BATS_TEST_FILENAME}")/.."
    "${ROOT}/scripts/load_file_structure.sh" "${ROOT}/tests/cases/downloads.json" "${BATS_FILE_TMPDIR}"
}


setup() {
    load 'helpers/load'
    common_setup
}


test_servarr_download() {
    local id="$1"

    local events="${ROOT}/tests/cases/${id}/download/events"
    local expected="${ROOT}/tests/cases/${id}/download/expected.json"
    local script="${ROOT}/scripts/support_extra_files.sh"

    for event in "${events}"/*; do
        mock_servarr_event "$event" "${BATS_TEST_TMPDIR}" "${BATS_FILE_TMPDIR}"
        run "$script"
    done

    while read -r line; do
        local source="${line%|*}"
        local target="${line#*|}"

        source="${BATS_FILE_TMPDIR}/${source#/}"
        target="${BATS_TEST_TMPDIR}/${target#/}"

        assert_file_exists "$target"
        assert_files_equal "$source" "$target"

        rm --force "$target"
    done <<< "$(json_to_kv "$expected")"

    run find "${BATS_TEST_TMPDIR}" -type f ! -name "movie.nfo" -name "s[0-9][0-9]e[0-9][0-9]-*.nfo"
    refute_output
}


@test "Memories (1995) [tmdbid-42994]" {
    test_servarr_download "tmdbid-42994"
}


@test "Neon Genesis Evangelion - The End of Evangelion (1997) [tmdbid-18491]" {
    test_servarr_download "tmdbid-18491"
}


@test "Chobits (2002) [tvdbid-72070]" {
    test_servarr_download "tvdbid-72070"
}


@test "Death Note (2006) [tvdbid-79481]" {
    test_servarr_download "tvdbid-79481"
}


@test "Elfen Lied (2004) [tvdbid-75941]" {
    test_servarr_download "tvdbid-75941"
}


@test "Fullmetal Alchemist (2003) [tvdbid-75579]" {
    test_servarr_download "tvdbid-75579"
}


@test "Monster Musume - Everyday Life with Monster Girls (2015) [tvdbid-293119]" {
    test_servarr_download "tvdbid-293119"
}


@test "Neon Genesis Evangelion (1995) [tvdbid-70350]" {
    test_servarr_download "tvdbid-70350"
}


@test "Night Warriors - DarkStalkers' Revenge (1997) [tvdbid-82119]" {
    test_servarr_download "tvdbid-82119"
}


@test "Record of Lodoss War (1990) [tvdbid-78777]" {
    test_servarr_download "tvdbid-78777"
}


@test "Slayers (1995) [tvdbid-77681]" {
    test_servarr_download "tvdbid-77681"
}


@test "Spice and Wolf (2008) [tvdbid-81178]" {
    test_servarr_download "tvdbid-81178"
}


@test "To LOVE-Ru (2008) [tvdbid-81831]" {
    test_servarr_download "tvdbid-81831"
}
