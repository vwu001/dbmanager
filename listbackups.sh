#!/bin/bash
# List GW-suite database backup sets found in branch folders.
# Usage: ./listbackups.sh [folder]
#   (no arg) scan every immediate subfolder of the repo
#   <folder> scan only that folder
# A backup set is identified by a "MM-DD_pcdb.sql" file in a folder.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${LISTBACKUPS_ROOT:-$SCRIPT_DIR}"

target="${1:-}"

if [ -n "$target" ]; then
  search_dirs="${ROOT}/${target}"
else
  search_dirs="$(find "$ROOT" -maxdepth 1 -mindepth 1 -type d)"
fi

found=0
for dir in $search_dirs; do
  [ -d "$dir" ] || continue
  folder="$(basename "$dir")"
  for f in "$dir"/*_pcdb.sql; do
    [ -e "$f" ] || continue
    found=1
    base="$(basename "$f")"
    date="${base%_pcdb.sql}"
    size="$(du -h "$f" | cut -f1)"
    echo "${folder}/${date}  (pcdb ${size})"
  done
done

if [ "$found" -eq 0 ]; then
  echo "No backups found."
fi
