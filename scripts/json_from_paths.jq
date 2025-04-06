#!/usr/bin/env -S jq -nRf

[
  inputs
  | select(endswith("/") == false)
]
| sort
| map(split("/"))
      # | map(sub("^$"; "/")))
