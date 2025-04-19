#!/usr/bin/env bash


mock_sonarr_series_add() {
    mkdir --parents "$sonarr_series_path"
}


mock_sonarr_download() {
    if [[ -n "$sonarr_isupgrade" ]]; then
    fi
}


mock_sonarr_rename() {
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
