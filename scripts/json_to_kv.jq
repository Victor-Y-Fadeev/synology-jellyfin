#!/usr/bin/env -S jq -nrf


def disassembler($folders; $files):
    ($folders | to_entries[]) as $entry
    | $entry.key as $source
    | $entry.value as $destination
    | $files
    | to_entries
    | map({"key": ($source + "/" + .key), "value": ($destination + "/" + .value)})
    | from_entries;


inputs
| map(disassembler(.[0]; .[1]))
| add
| to_entries
| map(.key + "|" + .value)[]
