def builder(path; value):
  value
  | if type == "object" then
    to_entries
    | map(.key as $key
          | builder(path + "/" + $key; .value))
    | .[]
  elif type == "array" then
    map(builder(path; .))
    | .[]
  else
    path + "/" + .
  end;

builder(""; .)
| .[1:]
| sub("/\\.?/"; "/")
