#!/usr/bin/env -S jq -nRSf


[
  inputs
  | split("|")
  | map(split("/")
        | (.[:-1] | join("/")) as $folder
        | [$folder, .[-1]])
  | [[{"key": .[0][0], "value": .[1][0]}],
     [{"key": .[0][1], "value": .[1][1]}]]
  | map(from_entries)
]
| group_by(.[0])
| map(.[0][0] as $group
      | map(.[1])
      | add
      | [$group, .])
