#!/usr/bin/env bash


mock_sonarr_series_add() {
}


mock_sonarr_download() {
}


mock_sonarr_rename() {
}


mock_sonarr_episode_file_delete() {
}


mock_sonarr_series_delete() {
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
