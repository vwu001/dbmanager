#!/bin/bash
# Back up a suite's localconfig (the tracked files modified from HEAD under the manifest
# pathspecs) to a LOCAL, gitignored location. Never committed.
#
# Usage: ./localconfig-backup.sh <root> <center>
# Writes to localconfig/backups/<root>/<center>/, including the real credentials.xml.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/localconfig-lib.sh"

root="${1:-}"; center="${2:-}"
if [ -z "$root" ] || [ -z "$center" ]; then
  echo "Usage: $0 <root> <center>" >&2
  exit 1
fi

suite="$(lc_suite_dir "$root" "$center")"
if [ ! -d "$suite" ]; then
  echo "Error: suite directory not found: $suite" >&2
  exit 1
fi

destbase="$LC_BACKUP_DIR/$root/$center"

files="$(lc_modified_files "$suite")"
if [ -z "$files" ]; then
  echo "No modified localconfig found under manifest paths for $root/$center. Nothing to back up."
  exit 0
fi

if [ -d "$destbase" ]; then
  echo "Warning: overwriting existing backup at $destbase"
fi

printf '%s\n' "$files" | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  mkdir -p "$destbase/$(dirname "$rel")"
  cp "$suite/$rel" "$destbase/$rel"
  echo "  + $rel"
done

count="$(printf '%s\n' "$files" | grep -c .)"
echo "Backed up $count localconfig file(s) into $destbase"
echo "(local + gitignored — never committed)."
