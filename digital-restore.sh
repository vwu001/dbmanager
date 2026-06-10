#!/bin/bash
# Restore a digital UI repo's backed-up config into its working tree.
#
# Usage: ./digital-restore.sh <repo>
# Copies every file under digital/backups/<repo>/ back to the same relative path in the
# repo, overwriting the working-tree copies.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/digital-lib.sh"

repo="${1:-}"
if [ -z "$repo" ]; then
  echo "Usage: $0 <repo>" >&2
  exit 1
fi

repodir="$(dg_repo_dir "$repo")"
srcbase="$DIGITAL_BACKUP_DIR/$repo"

if [ ! -d "$repodir" ]; then
  echo "Error: repo directory not found: $repodir" >&2
  exit 1
fi
if [ ! -d "$srcbase" ]; then
  echo "Error: no backup found at $srcbase. Run digital-backup.sh first." >&2
  exit 1
fi

find "$srcbase" -type f | while IFS= read -r src; do
  rel="${src#$srcbase/}"
  mkdir -p "$repodir/$(dirname "$rel")"
  cp "$src" "$repodir/$rel"
  echo "  -> $rel"
done

count="$(find "$srcbase" -type f | grep -c .)"
echo "Restored $count digital config file(s) into $repodir."
