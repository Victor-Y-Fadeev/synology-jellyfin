#!/usr/bin/env -S jq -nRSf


def builder:
  if length == 1 then
    {".": [.[0]]}
  else
    {(.[0]): .[1:] | builder}
  end;


def merger($lhs; $rhs):
  if $rhs | type == "object" then
    ($rhs | keys[0]) as $key
    | if $lhs | type != "object" then
      $rhs | .["."] += $lhs
    elif $lhs | has($key) then
      $lhs | .[$key] = merger(.[$key]; $rhs[$key])
    else
      $lhs + $rhs
    end
  elif $lhs | type == "object" then
    $lhs | .["."] += $rhs
  else
    $lhs + $rhs
  end;


def reducer:
  if length == 1 and keys[0] == "." then
    .[]
  else
    to_entries
    | map(.key as $key
          | if .value | type == "object" then
            .value
            | with_entries(.key |= $key + "/" + .)
            | reducer
            | to_entries[]
          else
            .key |= sub("/\\.$"; "")
          end)
    | from_entries
  end;


def compressor:
  to_entries
  | map(.key as $key
        | if (.value | has(".")) or (.key | endswith("]")) then
          .key |= sub("//"; "/")
          | .value |= reducer
        else
          .value
          | with_entries(.key |= $key + "/" + .)
          | compressor
          | to_entries[]
        end)
  | from_entries;


[
  inputs
  | select(endswith("/") == false)
  | split("/")
  | map(sub("^$"; "/"))
  | builder
]
| sort
| reduce .[] as $item ({}; merger(.; $item))
| compressor
