#!/bin/bash
# Tests for listbackups.sh using a fixture root.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
. "$HERE/assert.sh"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/r99" "$FIX/r88" "$FIX/notabackup"
# r99 has a full set for 05-01
for db in pcdb bcdb cmdb; do printf 'x' > "$FIX/r99/05-01_${db}.sql"; done
# r88 has a set for 03-10
for db in pcdb bcdb cmdb; do printf 'x' > "$FIX/r88/03-10_${db}.sql"; done
# notabackup has unrelated files only
printf 'x' > "$FIX/notabackup/readme.txt"

run() {
  OUT="$(LISTBACKUPS_ROOT="$FIX" bash "$REPO/listbackups.sh" "$@" 2>&1)"
  STATUS=$?
}

# List all
run
assert_status "$STATUS" 0 "listing all folders succeeds"
assert_contains "$OUT" "r99/05-01" "shows r99 backup date"
assert_contains "$OUT" "r88/03-10" "shows r88 backup date"
case "$OUT" in
  *notabackup*) printf 'FAIL - folder without backups is excluded\n'; ASSERT_FAILURES=$((ASSERT_FAILURES+1));;
  *) printf 'ok   - folder without backups is excluded\n';;
esac

# List a single folder
run r99
assert_contains "$OUT" "r99/05-01" "single-folder listing shows its date"
case "$OUT" in
  *r88*) printf 'FAIL - single-folder listing excludes other folders\n'; ASSERT_FAILURES=$((ASSERT_FAILURES+1));;
  *) printf 'ok   - single-folder listing excludes other folders\n';;
esac

# Empty result
EMPTY="$(mktemp -d)"
OUT="$(LISTBACKUPS_ROOT="$EMPTY" bash "$REPO/listbackups.sh" 2>&1)"; STATUS=$?
rm -rf "$EMPTY"
assert_contains "$OUT" "No backups found." "reports when nothing found"

done_tests
