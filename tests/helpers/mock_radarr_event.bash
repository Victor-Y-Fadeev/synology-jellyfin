#!/usr/bin/env bash


mock_radarr_movie_added() {
}


mock_radarr_download() {
}


mock_radarr_rename() {
}


mock_radarr_movie_file_delete() {
}


mock_radarr_movie_delete() {
}


mock_radarr_event() {
    case "$radarr_eventtype" in
        "MovieAdded")
            mock_radarr_movie_added
            ;;
        "Download")
            mock_radarr_download
            ;;
        "Rename")
            mock_radarr_rename
            ;;
        "MovieFileDelete")
            mock_radarr_movie_file_delete
            ;;
        "MovieDelete")
            mock_radarr_movie_delete
            ;;
    esac
}
