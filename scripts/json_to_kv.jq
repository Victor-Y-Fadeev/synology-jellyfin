#!/usr/bin/env -S jq -nrf


inputs
| map((.[0] | to_entries[]) as $entry
      | $entry.key as $source
      | $entry.value as $destination
      | .[1]
      | to_entries
      | map({"key": ($source + "/" + .key), "value": ($destination + "/" + .value)})
      | from_entries)
| add
| to_entries
| map(.key + "|" + .value)[]
