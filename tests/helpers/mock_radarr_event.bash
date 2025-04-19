#!/usr/bin/env bash


mock_radarr_movie_added() {
    mkdir --parents "$radarr_movie_path"
}


mock_radarr_download() {
}


mock_radarr_rename() {
}


mock_radarr_movie_file_delete() {
    rm --force "$radarr_moviefile_path"
}


mock_radarr_movie_delete() {
    if [[ "$radarr_movie_deletedfiles" == "True" ]]; then
        rm --force --recursive "$radarr_movie_path"
    fi
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
