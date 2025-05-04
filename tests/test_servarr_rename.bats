#!/usr/bin/env bats
bats_require_minimum_version 1.5.0


setup_file() {
    ROOT="$(dirname "${BATS_TEST_FILENAME}")/.."
    ROOT="$(realpath "${ROOT}")"

    "${ROOT}/scripts/load_file_structure.sh" "${ROOT}/tests/cases/movies.json" "${BATS_FILE_TMPDIR}"
    "${ROOT}/scripts/load_file_structure.sh" "${ROOT}/tests/cases/series.json" "${BATS_FILE_TMPDIR}"
}


setup() {
    load "helpers/load"
    common_setup

    BATSLIB_FILE_PATH_REM="#${BATS_FILE_TMPDIR}"
}


test_servarr_rename() {
    local id="$1"

    local events="${ROOT}/tests/cases/${id}/rename/events"
    local expected="${ROOT}/tests/cases/${id}/rename/expected.json"
    local script="${ROOT}/scripts/support_extra_files.sh"

    for event in "${events}"/*; do
        mock_servarr_event "$event" "${BATS_FILE_TMPDIR}" "${BATS_FILE_TMPDIR}"
        run --separate-stderr "$script"
        refute_stderr
        assert_success
    done

    while read -r line; do
        local source="${line%|*}"
        local target="${line#*|}"

        local source_path="${BATS_FILE_TMPDIR}/${source#/}"
        local target_path="${BATS_FILE_TMPDIR}/${target#/}"

        assert_file_not_exists "$source_path"
        assert_file_exists "$target_path"

        run cat "$target_path"
        assert_output "$source"

        local directory="$(dirname "$source_path")"
        if [[ "$directory" != "$(dirname "$target_path")" ]]; then
            directory="$(dirname "$directory")"
        fi

        run bats_pipe find "$directory" -type d -empty \
                    \| sed "s|^${BATS_FILE_TMPDIR}||"
        refute_output
    done <<< "$(json_to_kv "$expected")"
}


# bats test_tags=rename, tmdbid-42994
@test "Memories (1995) [tmdbid-42994]" {
    test_servarr_rename "tmdbid-42994"
}


# bats test_tags=rename, tmdbid-18491
@test "Neon Genesis Evangelion - The End of Evangelion (1997) [tmdbid-18491]" {
    test_servarr_rename "tmdbid-18491"
}


# bats test_tags=rename, tvdbid-72070
@test "Chobits (2002) [tvdbid-72070]" {
    test_servarr_rename "tvdbid-72070"
}


# bats test_tags=rename, tvdbid-79481
@test "Death Note (2006) [tvdbid-79481]" {
    test_servarr_rename "tvdbid-79481"
}


# bats test_tags=rename, tvdbid-75941
@test "Elfen Lied (2004) [tvdbid-75941]" {
    test_servarr_rename "tvdbid-75941"
}


# bats test_tags=rename, tvdbid-75579
@test "Fullmetal Alchemist (2003) [tvdbid-75579]" {
    test_servarr_rename "tvdbid-75579"
}


# bats test_tags=rename, tvdbid-293119
@test "Monster Musume - Everyday Life with Monster Girls (2015) [tvdbid-293119]" {
    test_servarr_rename "tvdbid-293119"
}


# bats test_tags=rename, tvdbid-70350
@test "Neon Genesis Evangelion (1995) [tvdbid-70350]" {
    test_servarr_rename "tvdbid-70350"
}


# bats test_tags=rename, tvdbid-82119
@test "Night Warriors - DarkStalkers' Revenge (1997) [tvdbid-82119]" {
    test_servarr_rename "tvdbid-82119"
}


# bats test_tags=rename, tvdbid-78777
@test "Record of Lodoss War (1990) [tvdbid-78777]" {
    test_servarr_rename "tvdbid-78777"
}


# bats test_tags=rename, tvdbid-77681
@test "Slayers (1995) [tvdbid-77681]" {
    test_servarr_rename "tvdbid-77681"
}


# bats test_tags=rename, tvdbid-81178
@test "Spice and Wolf (2008) [tvdbid-81178]" {
    test_servarr_rename "tvdbid-81178"
}


# bats test_tags=rename, tvdbid-81831
@test "To LOVE-Ru (2008) [tvdbid-81831]" {
    test_servarr_rename "tvdbid-81831"
}
