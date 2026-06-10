#!/bin/bash
# Back up a digital UI repo's local config (.env, .npmrc, src/config/config.json — the
# tracked files modified from HEAD) to a LOCAL, gitignored location. Never committed.
#
# Usage: ./digital-backup.sh <repo>          (e.g. agentquotehome | agentexperience)
# Writes to digital/backups/<repo>/, including the real .npmrc token and .env.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/digital-lib.sh"

repo="${1:-}"
if [ -z "$repo" ]; then
  echo "Usage: $0 <repo>" >&2
  exit 1
fi

repodir="$(dg_repo_dir "$repo")"
if [ ! -d "$repodir" ]; then
  echo "Error: repo directory not found: $repodir" >&2
  exit 1
fi

destbase="$DIGITAL_BACKUP_DIR/$repo"

files="$(dg_modified_files "$repodir")"
if [ -z "$files" ]; then
  echo "No modified digital config found under manifest paths for $repo. Nothing to back up."
  exit 0
fi

if [ -d "$destbase" ]; then
  echo "Warning: overwriting existing backup at $destbase"
fi

printf '%s\n' "$files" | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  mkdir -p "$destbase/$(dirname "$rel")"
  cp "$repodir/$rel" "$destbase/$rel"
  echo "  + $rel"
done

count="$(printf '%s\n' "$files" | grep -c .)"
echo "Backed up $count digital config file(s) into $destbase"
echo "(local + gitignored — never committed)."
