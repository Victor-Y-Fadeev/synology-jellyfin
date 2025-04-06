#!/bin/bash

set -e


function json_to_paths {
    echo "${1:-"$(cat)"}" | jq -r 'def builder(path; value): value |
        if type == "object" then
            to_entries | map(.key as $key | builder(path + "/" + $key; .value)) | .[]
        elif type == "array" then
            map(builder(path; .)) | .[]
        else
            path + "/" + .
        end; builder(""; .) | .[1:] | sub("/\\.?/"; "/")'
}


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if  (( $# > 0 )); then
        json_to_paths "$(cat "$1")"
    else
        json_to_paths
    fi
fi
