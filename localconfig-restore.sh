#!/bin/bash
# Restore a previously backed-up localconfig into a suite working tree.
#
# Usage: ./localconfig-restore.sh <root> <center>
# Copies every file under localconfig/backups/<root>/<center>/ back to the same relative
# path in the suite, overwriting the working-tree copies.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/localconfig-lib.sh"

root="${1:-}"; center="${2:-}"
if [ -z "$root" ] || [ -z "$center" ]; then
  echo "Usage: $0 <root> <center>" >&2
  exit 1
fi

suite="$(lc_suite_dir "$root" "$center")"
srcbase="$LC_BACKUP_DIR/$root/$center"

if [ ! -d "$suite" ]; then
  echo "Error: suite directory not found: $suite" >&2
  exit 1
fi
if [ ! -d "$srcbase" ]; then
  echo "Error: no backup found at $srcbase. Run localconfig-backup.sh first." >&2
  exit 1
fi

count=0
find "$srcbase" -type f | while IFS= read -r src; do
  rel="${src#$srcbase/}"
  mkdir -p "$suite/$(dirname "$rel")"
  cp "$src" "$suite/$rel"
  echo "  -> $rel"
done

count="$(find "$srcbase" -type f | grep -c .)"
echo "Restored $count localconfig file(s) into $suite."
