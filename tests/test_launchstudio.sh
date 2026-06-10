#!/bin/bash
# Tests for launchstudio.sh using a fixture bamboo root + DRY_RUN.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
. "$HERE/assert.sh"

# Build a fake bamboo root with an executable gwb under gw43/policycenter
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/gw43/policycenter"
printf '#!/bin/bash\n' > "$FIX/gw43/policycenter/gwb"
chmod +x "$FIX/gw43/policycenter/gwb"

run() {
  # run <args...> ; captures OUT and STATUS
  OUT="$(BAMBOO_ROOT="$FIX" DRY_RUN=1 \
        IDEA_CE_HOME=/CE IDEA_UT_HOME=/UT STUDIO_JAVA_HOME=/JAVA21 \
        bash "$REPO/launchstudio.sh" "$@" 2>&1)"
  STATUS=$?
}

# Default edition -> Community
run gw43 policycenter
assert_status "$STATUS" 0 "gw43 policycenter launches (dry run)"
assert_contains "$OUT" "IDEA_HOME=/CE" "default edition uses Community IDEA_HOME"
assert_contains "$OUT" "JAVA_HOME=/JAVA21" "uses Java 21 home"
assert_contains "$OUT" "CMD=$FIX/gw43/policycenter/gwb studio" "builds correct launch command"

# Ultimate edition -> UT
run gw43 policycenter --ultimate
assert_contains "$OUT" "IDEA_HOME=/UT" "--ultimate uses Ultimate IDEA_HOME"
assert_status "$STATUS" 0 "--ultimate launches successfully"

# Excluded snapshot-only root
run gw policycenter
assert_status "$STATUS" 1 "snapshot-only root 'gw' is rejected"
assert_contains "$OUT" "snapshot-only" "rejection message explains why"

run gw-r1-tx policycenter
assert_status "$STATUS" 1 "snapshot-only root 'gw-r1-tx' is rejected"

# Missing studio path
run gw43 nosuchcenter
assert_status "$STATUS" 1 "missing center path is rejected"
assert_contains "$OUT" "not found" "missing path message"

# Missing args
run gw43
assert_status "$STATUS" 1 "missing center arg shows usage"
assert_contains "$OUT" "Usage:" "usage message printed"

# Unknown third option
run gw43 policycenter --bogus
assert_status "$STATUS" 1 "unknown option is rejected"
assert_contains "$OUT" "unknown option" "unknown-option message printed"

done_tests
