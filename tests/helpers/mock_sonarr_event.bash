#!/usr/bin/env bash


mock_sonarr_series_add() {
    mkdir --parents "$sonarr_series_path"
}


mock_sonarr_download() {
    if [[ -n "$sonarr_isupgrade" ]]; then
        mkdir --parents "$(dirname "$sonarr_episodefile_path")"

        if ! ln --force "$sonarr_episodefile_sourcepath" "$sonarr_episodefile_path" &>/dev/null; then
            cp --force "$sonarr_episodefile_sourcepath" "$sonarr_episodefile_path"
        fi
    fi
}


mock_sonarr_rename() {
    local previouspaths, paths, i
    readarray -d '|' -t previouspaths <<< "$sonarr_episodefile_previouspaths"
    readarray -d '|' -t paths <<< "$sonarr_episodefile_paths"

    for (( i = 0; i < "${#paths[@]}"; ++i )); do
        mv --force "${previouspaths[$i]}" "${paths[$i]}"
    done
}


mock_sonarr_episode_file_delete() {
    rm --force "$sonarr_episodefile_path"
}


mock_sonarr_series_delete() {
    if [[ "$sonarr_series_deletedfiles" == "True" ]]; then
        rm --force --recursive "$sonarr_series_path"
    fi
}


mock_sonarr_event() {
    case "$sonarr_eventtype" in
        "SeriesAdd")
            mock_sonarr_series_add
            ;;
        "Download")
            mock_sonarr_download
            ;;
        "Rename")
            mock_sonarr_rename
            ;;
        "EpisodeFileDelete")
            mock_sonarr_episode_file_delete
            ;;
        "SeriesDelete")
            mock_sonarr_series_delete
            ;;
    esac
}
