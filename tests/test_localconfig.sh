#!/bin/bash
# Tests the REAL localconfig/manifest.txt pathspecs against a fixture suite checkout.
# Never touches a real checkout or the real backups.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
. "$HERE/assert.sh"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
S="$FIX/suite"

mk() { mkdir -p "$(dirname "$S/$1")"; printf 'original\n' > "$S/$1"; }
CFG=modules/configuration
mk "$CFG/config/config.local.properties"
mk "$CFG/config/database-config.xml"
mk "$CFG/credentials.xml"
mk "$CFG/config/plugin/registry/ContactSystemPlugin.gwp"
mk "$CFG/gsrc/bamboo/integration/rest/fireline/FirelineService.gs"
mk "$CFG/gsrc/bamboo/integration/rest/guycarp/GuyCarpService.gs"
mk "$CFG/gsrc/bamboo/integration/Direct.gs"
mk "$CFG/gsrc/bamboo/integration/sircon/tmp/pending/Sample.csv"
mk "$CFG/gsrc/bamboo/lob/NotAnIntegration.gs"
mk "$CFG/deploy/resources/js/gen/all.js"
mk "$CFG/config/untouched.xml"

( cd "$S" && git init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )

# Modify everything except the file that must stay unmodified.
for f in "$CFG/config/config.local.properties" "$CFG/config/database-config.xml" \
         "$CFG/credentials.xml" "$CFG/config/plugin/registry/ContactSystemPlugin.gwp" \
         "$CFG/gsrc/bamboo/integration/rest/fireline/FirelineService.gs" \
         "$CFG/gsrc/bamboo/integration/rest/guycarp/GuyCarpService.gs" \
         "$CFG/gsrc/bamboo/integration/Direct.gs" \
         "$CFG/gsrc/bamboo/integration/sircon/tmp/pending/Sample.csv" \
         "$CFG/gsrc/bamboo/lob/NotAnIntegration.gs" \
         "$CFG/deploy/resources/js/gen/all.js"; do
  printf 'changed\n' > "$S/$f"
done

. "$REPO/localconfig-lib.sh"
OUT="$(lc_modified_files "$S")"

captured()     { case "$OUT" in *"$1"*) printf 'ok   - captures %s\n' "$2";;
                 *) printf 'FAIL - captures %s\n      got: %s\n' "$2" "$OUT"
                    ASSERT_FAILURES=$((ASSERT_FAILURES+1));; esac; }
not_captured() { case "$OUT" in *"$1"*) printf 'FAIL - excludes %s\n      got: %s\n' "$2" "$OUT"
                    ASSERT_FAILURES=$((ASSERT_FAILURES+1));;
                 *) printf 'ok   - excludes %s\n' "$2";; esac; }

captured "config.local.properties"  "config.local.properties"
captured "database-config.xml"      "database-config.xml"
captured "credentials.xml"          "credentials.xml"
captured "ContactSystemPlugin.gwp"  "a modified plugin registry .gwp"
captured "FirelineService.gs"       "an integration service .gs override"
captured "GuyCarpService.gs"        "a second integration .gs override"
captured "Direct.gs"                "a .gs directly under integration/ (shell-glob trap)"

not_captured "Sample.csv"           "integration sample data (.csv)"
not_captured "NotAnIntegration.gs"  ".gs outside the integration tree"
not_captured "all.js"               "generated all.js"
not_captured "untouched.xml"        "an unmodified file"

done_tests
