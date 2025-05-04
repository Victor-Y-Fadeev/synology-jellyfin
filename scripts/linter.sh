#!/bin/bash

set -e


DIR="$(dirname "${BASH_SOURCE[0]}")"
ROOT="$(realpath "${DIR}/..")"


if ! command -v shellcheck &>/dev/null; then
    sudo apt --yes install shellcheck
fi


# Warning:
#   https://www.shellcheck.net/wiki/SC2034 -- Variable appears unused. Verify use (or export if used externally).
#   https://www.shellcheck.net/wiki/SC2154 -- Variable is referenced but not assigned.
#   https://www.shellcheck.net/wiki/SC2155 -- Declare and assign separately to avoid masking return values.
#
# Info:
#   https://www.shellcheck.net/wiki/SC2249 -- Consider adding a default *) case, even if it just exits with error.
#   https://www.shellcheck.net/wiki/SC2311 -- Bash implicitly disabled set -e for this function invocation because it's inside a command substitution.
#                                             Add set -e; before it or enable inherit_errexit.
#   https://www.shellcheck.net/wiki/SC2312 -- Consider invoking this command separately to avoid masking its return value (or use '|| true' to ignore).
#
# Style:
#   https://www.shellcheck.net/wiki/SC2001 -- See if you can use ${variable//search/replace} instead.
#   https://www.shellcheck.net/wiki/SC2250 -- Prefer putting braces around variable references even when not strictly required.


shellcheck --color=always --enable=all --exclude=SC2034,SC2154,SC2155,SC2249,SC2311,SC2312,SC2001,SC2250 \
    "${ROOT}"/scripts/*.sh \
    "${ROOT}"/tests/*.bats \
    "${ROOT}"/tests/helpers/*.bash
