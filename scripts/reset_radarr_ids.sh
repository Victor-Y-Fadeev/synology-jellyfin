#!/bin/bash

set -e

DIR="$(dirname "${BASH_SOURCE[0]}")"
DB="${DIR}/../config/radarr/radarr.db"

if ! dpkg --status sqlite3 &>/dev/null; then
    sudo apt --yes install sqlite3
fi

sqlite3 "$DB" "UPDATE sqlite_sequence
               SET seq = 0
               WHERE name IN ('MovieFiles', 'Movies', 'History');"

sqlite3 "$DB" "SELECT name, seq
               FROM sqlite_sequence
               WHERE name IN ('MovieFiles', 'Movies', 'History');"
