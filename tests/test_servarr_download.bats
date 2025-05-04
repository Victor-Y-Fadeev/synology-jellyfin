#!/usr/bin/env bats
bats_require_minimum_version 1.5.0


setup_file() {
    ROOT="$(dirname "${BATS_TEST_FILENAME}")/.."
    ROOT="$(realpath "${ROOT}")"

    "${ROOT}/scripts/load_file_structure.sh" "${ROOT}/tests/cases/downloads.json" "${BATS_FILE_TMPDIR}"
}


setup() {
    load "helpers/load"
    common_setup

    shopt -s extglob
    BATSLIB_FILE_PATH_REM="#@(${BATS_TEST_TMPDIR}|${BATS_FILE_TMPDIR})"
}


test_servarr_download() {
    local id="$1"

    local events="${ROOT}/tests/cases/${id}/download/events"
    local expected="${ROOT}/tests/cases/${id}/download/expected.json"
    local script="${ROOT}/scripts/support_extra_files2.sh"

    for event in "${events}"/*; do
        mock_servarr_event "$event" "${BATS_TEST_TMPDIR}" "${BATS_FILE_TMPDIR}"
        run --separate-stderr "$script"
        refute_stderr
        assert_success
    done

    while read -r line; do
        local source="${line%|*}"
        local target="${line#*|}"

        local source_path="${BATS_FILE_TMPDIR}/${source#/}"
        local target_path="${BATS_TEST_TMPDIR}/${target#/}"

        assert_file_exists "$target_path"
        assert_files_equal "$source_path" "$target_path"

        rm --force "$target_path"
    done <<< "$(json_to_kv "$expected")"

    run bats_pipe find "${BATS_TEST_TMPDIR}" -type f \
                    ! -name "movie.nfo" \
                    ! -name "s[0-9][0-9]e[0-9][0-9]-*.nfo" \
                    ! -name "separate-stderr-*" \
                \| sed "s|^${BATS_TEST_TMPDIR}||"
    refute_output
}


# bats test_tags=download, tmdbid-42994
@test "Memories (1995) [tmdbid-42994]" {
    test_servarr_download "tmdbid-42994"
}


# bats test_tags=download, tmdbid-18491
@test "Neon Genesis Evangelion - The End of Evangelion (1997) [tmdbid-18491]" {
    test_servarr_download "tmdbid-18491"
}


# bats test_tags=download, tvdbid-72070
@test "Chobits (2002) [tvdbid-72070]" {
    test_servarr_download "tvdbid-72070"
}


# bats test_tags=download, tvdbid-79481
@test "Death Note (2006) [tvdbid-79481]" {
    test_servarr_download "tvdbid-79481"
}


# bats test_tags=download, tvdbid-75941
@test "Elfen Lied (2004) [tvdbid-75941]" {
    test_servarr_download "tvdbid-75941"
}


# bats test_tags=download, tvdbid-75579
@test "Fullmetal Alchemist (2003) [tvdbid-75579]" {
    test_servarr_download "tvdbid-75579"
}


# bats test_tags=download, tvdbid-293119
@test "Monster Musume - Everyday Life with Monster Girls (2015) [tvdbid-293119]" {
    test_servarr_download "tvdbid-293119"
}


# bats test_tags=download, tvdbid-70350
@test "Neon Genesis Evangelion (1995) [tvdbid-70350]" {
    test_servarr_download "tvdbid-70350"
}


# bats test_tags=download, tvdbid-82119
@test "Night Warriors - DarkStalkers' Revenge (1997) [tvdbid-82119]" {
    test_servarr_download "tvdbid-82119"
}


# bats test_tags=download, tvdbid-78777
@test "Record of Lodoss War (1990) [tvdbid-78777]" {
    test_servarr_download "tvdbid-78777"
}


# bats test_tags=download, tvdbid-77681
@test "Slayers (1995) [tvdbid-77681]" {
    test_servarr_download "tvdbid-77681"
}


# bats test_tags=download, tvdbid-81178
@test "Spice and Wolf (2008) [tvdbid-81178]" {
    test_servarr_download "tvdbid-81178"
}


# bats test_tags=download, tvdbid-81831
@test "To LOVE-Ru (2008) [tvdbid-81831]" {
    test_servarr_download "tvdbid-81831"
}
