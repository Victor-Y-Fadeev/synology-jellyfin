setup_file() {
    ROOT="$(dirname "${BATS_TEST_FILENAME}")/.."
    "${ROOT}/scripts/load_file_structure.sh" "${ROOT}/tests/cases/movies.json" "${BATS_FILE_TMPDIR}"
    "${ROOT}/scripts/load_file_structure.sh" "${ROOT}/tests/cases/series.json" "${BATS_FILE_TMPDIR}"
}


setup() {
    load "helpers/load"
    common_setup
}


test_servarr_delete() {
    local id="$1"

    local events="${ROOT}/tests/cases/${id}/delete/events"
    local expected="${ROOT}/tests/cases/${id}/delete/expected.json"
    local script="${ROOT}/scripts/support_extra_files.sh"

    for event in "${events}"/*; do
        mock_servarr_event "$event" "${BATS_FILE_TMPDIR}" "${BATS_FILE_TMPDIR}"
        run "$script"
    done

    while read -r line; do
        assert_file_not_exists "${BATS_FILE_TMPDIR}/${line#/}"
    done <<< "$(json_to_paths "$expected")"
}


@test "Memories (1995) [tmdbid-42994]" {
    test_servarr_delete "tmdbid-42994"
}


@test "Neon Genesis Evangelion - The End of Evangelion (1997) [tmdbid-18491]" {
    test_servarr_delete "tmdbid-18491"
}


@test "Chobits (2002) [tvdbid-72070]" {
    test_servarr_delete "tvdbid-72070"
}


@test "Death Note (2006) [tvdbid-79481]" {
    test_servarr_delete "tvdbid-79481"
}


@test "Elfen Lied (2004) [tvdbid-75941]" {
    test_servarr_delete "tvdbid-75941"
}


@test "Fullmetal Alchemist (2003) [tvdbid-75579]" {
    test_servarr_delete "tvdbid-75579"
}


@test "Monster Musume - Everyday Life with Monster Girls (2015) [tvdbid-293119]" {
    test_servarr_delete "tvdbid-293119"
}


@test "Neon Genesis Evangelion (1995) [tvdbid-70350]" {
    test_servarr_delete "tvdbid-70350"
}


@test "Night Warriors - DarkStalkers' Revenge (1997) [tvdbid-82119]" {
    test_servarr_delete "tvdbid-82119"
}


@test "Record of Lodoss War (1990) [tvdbid-78777]" {
    test_servarr_delete "tvdbid-78777"
}


@test "Slayers (1995) [tvdbid-77681]" {
    test_servarr_delete "tvdbid-77681"
}


@test "Spice and Wolf (2008) [tvdbid-81178]" {
    test_servarr_delete "tvdbid-81178"
}


@test "To LOVE-Ru (2008) [tvdbid-81831]" {
    test_servarr_delete "tvdbid-81831"
}
