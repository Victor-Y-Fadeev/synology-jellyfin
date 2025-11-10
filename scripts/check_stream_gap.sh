#!/bin/bash

set -e


INPUT="$1"
STREAM="${2:-v}"
GAP="${3:-0.002}"


ffprobe -loglevel quiet -select_streams "${STREAM}" -show_entries frame=pts_time -print_format json "${INPUT}" \
    | jq --argjson gap "${GAP}" '
        def step($prev; $next):
            { prev: $prev, next: $next, diff: (if $prev | type == "object" then
                ($next.diff - $prev.diff) * 1000 | round / 1000
            else
                ($next - $prev) * 1000 | round / 1000
            end )};

        def diff:
            reduce .[1:][] as $item ({ prev: .[0], out: [] };
                .out += [step(.prev; $item)]
                | .prev = $item
            ) | .out;

        .frames | map(.pts_time | tonumber) | diff | diff
                | map(select(.diff > $gap) | if .prev.diff > 0 then
                        { time: .next.prev, duration: .next.diff, gap: .diff }
                    else
                        { time: .prev.prev, duration: .prev.diff, gap: .diff }
                    end)'
