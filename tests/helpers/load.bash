#!/usr/bin/env bash


SOURCE="$(realpath "${BASH_SOURCE[0]}")"
HELPERS="$(dirname "${SOURCE}")"


source "${HELPERS}/json_tools.bash"
source "${HELPERS}/mock_servarr_event.bash"
