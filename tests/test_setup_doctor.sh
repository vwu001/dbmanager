#!/bin/bash
# Tests for setup-doctor.sh using fixture roots and a stubbed PATH.
# Never touches the real checkouts, databases, or IDE installs.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
. "$HERE/assert.sh"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

# --- fixture: a fully healthy environment -----------------------------------
BAMBOO="$FIX/bamboo"
mkdir -p "$BAMBOO/gw43/policycenter" "$BAMBOO/gw43/billingcenter" "$BAMBOO/gw43/contactmanager"
for c in policycenter billingcenter contactmanager; do
  printf '#!/bin/bash\n' > "$BAMBOO/gw43/$c/gwb"; chmod +x "$BAMBOO/gw43/$c/gwb"
  mkdir -p "$BAMBOO/gw43/$c/modules/configuration/config"
done

# Write a database-config.xml whose ACTIVE (no env=) block is postgres or h2.
# Always includes a commented-out block of the other kind, plus an env="h2mem" block,
# so the parser is forced to ignore both.
write_dbconfig() {  # <center_dir> <postgres|h2> <db> <user>
  if [ "$2" = postgres ]; then
    cat > "$1/modules/configuration/config/database-config.xml" <<XML
<database-config>
  <!-- H2 (demo only)
  <database autoupgrade="full" dbtype="h2" name="D">
    <dbcp-connection-pool jdbc-url="jdbc:h2:file:./tmp/x"/>
  </database>
  -->
  <database autoupgrade="full" dbtype="h2" env="h2mem" name="D">
    <dbcp-connection-pool jdbc-url="jdbc:h2:mem:/tmp/x"/>
  </database>
  <database
    name="D"
    autoupgrade="full"
    dbtype="postgresql">
    <dbcp-connection-pool
      jdbc-url="jdbc:postgresql://localhost:5432/$3?user=$4&amp;password=x">
    </dbcp-connection-pool>
  </database>
</database-config>
XML
  else
    cat > "$1/modules/configuration/config/database-config.xml" <<XML
<database-config>
  <database autoupgrade="full" dbtype="h2" name="D">
    <dbcp-connection-pool jdbc-url="jdbc:h2:file:./tmp/x"/>
  </database>
  <database autoupgrade="full" dbtype="h2" env="h2mem" name="D">
    <dbcp-connection-pool jdbc-url="jdbc:h2:mem:/tmp/x"/>
  </database>
  <!-- PostgreSQL
  <database name="D" autoupgrade="full" dbtype="postgresql">
    <dbcp-connection-pool jdbc-url="jdbc:postgresql://localhost:5432/$3?user=$4&amp;password=x"/>
  </database>
  -->
</database-config>
XML
  fi
}
write_dbconfig "$BAMBOO/gw43/policycenter"  postgres pcdb pcuser
write_dbconfig "$BAMBOO/gw43/billingcenter" postgres bcdb bcuser
write_dbconfig "$BAMBOO/gw43/contactmanager" postgres cmdb cmuser
DIGITAL="$BAMBOO/gw"
mkdir -p "$DIGITAL/agentquotehome" "$DIGITAL/agentexperience"
for r in agentquotehome agentexperience; do
  mkdir -p "$DIGITAL/$r/node_modules"
  printf '20.11.0\n' > "$DIGITAL/$r/.nvmrc"
  printf '{"name":"%s","engines":{"node":">= 20.11.0 < 21","npm":">=9"}}\n' "$r" \
    > "$DIGITAL/$r/package.json"
done
IDEA_CE="$FIX/idea-ce/Contents"; mkdir -p "$IDEA_CE"
JAVA="$FIX/jdk/Contents/Home"; mkdir -p "$JAVA/bin"

# Stub bin: psql/createdb/node/npm that behave like a healthy machine.
BIN="$FIX/bin"; mkdir -p "$BIN"
# Stub psql driven by files the test rewrites: DBS, ROLES, EXTS.
printf 'pcdb bcdb cmdb postgres\n'               > "$FIX/DBS"
printf 'vincentwu pcuser bcuser cmuser postgres\n' > "$FIX/ROLES"
printf 'postgis file_fdw pg_stat_statements pgcrypto unaccent\n' > "$FIX/EXTS"
cat > "$BIN/psql" <<PSQL
#!/bin/bash
q=""
for a in "\$@"; do case "\$prev" in -c|-tAc) q="\$a";; esac; prev="\$a"; done
case "\$* " in
  *-l\ *|*--list*) tr ' ' '\n' < "$FIX/DBS"; exit 0;;
esac
case "\$q" in
  *pg_roles*)              tr ' ' '\n' < "$FIX/ROLES"; exit 0;;
  *pg_available_extensions*|*pg_extension*) tr ' ' '\n' < "$FIX/EXTS"; exit 0;;
esac
exit 0
PSQL
printf '#!/bin/bash\nexit 0\n' > "$BIN/pg_dump"
printf '#!/bin/bash\nexit 0\n' > "$BIN/createdb"
printf '#!/bin/bash\nexit 0\n' > "$BIN/dropdb"
printf '#!/bin/bash\necho v20.11.0\n'  > "$BIN/node"
printf '#!/bin/bash\necho 10.2.4\n'    > "$BIN/npm"
chmod +x "$BIN"/*

run() {  # run [extra env assignments via caller's DOCTOR_* exports]
  OUT="$(PATH="$BIN:/usr/bin:/bin" \
         BAMBOO_ROOT="$BAMBOO" \
         DIGITAL_ROOT="$DIGITAL" \
         IDEA_CE_HOME="$IDEA_CE" \
         IDEA_UT_HOME="$FIX/absent-ut/Contents" \
         STUDIO_JAVA_HOME="$JAVA" \
         DOCTOR_ROOTS="${DOCTOR_ROOTS:-gw43}" \
         DOCTOR_SKIP_ENV="${DOCTOR_SKIP_ENV:-1}" \
         DOCTOR_NODE_VERSION="${DOCTOR_NODE_VERSION:-20.11.0}" \
         bash "$REPO/setup-doctor.sh" "$@" 2>&1)"
  STATUS=$?
}

# --- healthy environment ----------------------------------------------------
run
assert_status "$STATUS" 0 "healthy environment exits 0"
assert_contains "$OUT" "All required checks passed" "healthy run reports success"
assert_contains "$OUT" "pcdb" "reports on the pcdb database"
assert_contains "$OUT" "policycenter" "reports on the policycenter checkout"
assert_contains "$OUT" "agentquotehome" "reports on the digital repos"

# Ultimate IDE is absent but optional -> must not fail the run
assert_contains "$OUT" "warn" "absent optional Ultimate IDE is a warning, not a failure"

assert_contains "$OUT" "satisfies the version requirement" "node matching the pin passes"

# --- node in the engines range but not the exact .nvmrc pin -> still OK ------
DOCTOR_NODE_VERSION=20.19.4 run
assert_status "$STATUS" 0 "node differing from .nvmrc but inside engines range exits 0"
assert_contains "$OUT" "in range, so fine" "an in-range version is not reported as a problem"

# --- node below the engines minimum -> fail ---------------------------------
DOCTOR_NODE_VERSION=17.9.1 run
assert_status "$STATUS" 1 "node below the engines minimum exits 1"
assert_contains "$OUT" "below the required 20.11.0" "names the minimum the repo requires"
assert_contains "$OUT" "nvm use" "suggests nvm use to fix an out-of-range node"

# --- node at/above the exclusive maximum -> fail ----------------------------
DOCTOR_NODE_VERSION=21.0.0 run
assert_status "$STATUS" 1 "node at the exclusive maximum exits 1"
assert_contains "$OUT" "unsupported 21" "names the unsupported ceiling"

# --- missing suite checkout -------------------------------------------------
mv "$BAMBOO/gw43/billingcenter" "$BAMBOO/gw43/.billingcenter-hidden"
run
assert_status "$STATUS" 1 "missing suite checkout exits 1"
assert_contains "$OUT" "billingcenter" "names the missing checkout"
mv "$BAMBOO/gw43/.billingcenter-hidden" "$BAMBOO/gw43/billingcenter"

# --- a center set to H2 skips the postgres-only checks ----------------------
write_dbconfig "$BAMBOO/gw43/policycenter"   h2 pcdb pcuser
write_dbconfig "$BAMBOO/gw43/billingcenter"  h2 bcdb bcuser
write_dbconfig "$BAMBOO/gw43/contactmanager" h2 cmdb cmuser
printf '\n' > "$FIX/DBS"; printf '\n' > "$FIX/ROLES"; printf '\n' > "$FIX/EXTS"
run
assert_status "$STATUS" 0 "all-H2 setup passes without any postgres databases"
assert_contains "$OUT" "H2" "reports that the centers are on H2"
# restore postgres fixtures
printf 'pcdb bcdb cmdb postgres\n'                > "$FIX/DBS"
printf 'vincentwu pcuser bcuser cmuser postgres\n' > "$FIX/ROLES"
printf 'postgis file_fdw pg_stat_statements pgcrypto unaccent\n' > "$FIX/EXTS"
write_dbconfig "$BAMBOO/gw43/policycenter"   postgres pcdb pcuser
write_dbconfig "$BAMBOO/gw43/billingcenter"  postgres bcdb bcuser
write_dbconfig "$BAMBOO/gw43/contactmanager" postgres cmdb cmuser

# --- postgres path: the app login role must exist ---------------------------
printf 'vincentwu bcuser cmuser postgres\n' > "$FIX/ROLES"
run
assert_status "$STATUS" 1 "missing app login role exits 1"
assert_contains "$OUT" "pcuser" "names the missing app login role"
assert_contains "$OUT" "CREATE ROLE" "suggests how to create the missing role"
printf 'vincentwu pcuser bcuser cmuser postgres\n' > "$FIX/ROLES"

# --- postgres path: required extensions must be available -------------------
printf 'file_fdw pg_stat_statements pgcrypto unaccent\n' > "$FIX/EXTS"
run
assert_status "$STATUS" 1 "missing postgres extension exits 1"
assert_contains "$OUT" "postgis" "names the missing extension"
printf 'postgis file_fdw pg_stat_statements pgcrypto unaccent\n' > "$FIX/EXTS"

# --- missing database -------------------------------------------------------
cat > "$BIN/psql" <<'PSQL'
#!/bin/bash
for a in "$@"; do
  case "$a" in
    -l|--list) printf 'pcdb\npostgres\n'; exit 0;;
  esac
done
exit 0
PSQL
chmod +x "$BIN/psql"
run
assert_status "$STATUS" 1 "missing database exits 1"
assert_contains "$OUT" "bcdb" "names the missing database"
assert_contains "$OUT" "createdb" "suggests how to create the missing database"

# --- postgres server unreachable -------------------------------------------
printf '#!/bin/bash\nexit 2\n' > "$BIN/psql"; chmod +x "$BIN/psql"
run
assert_status "$STATUS" 1 "unreachable postgres exits 1"
assert_contains "$OUT" "PostgreSQL" "reports the postgres connectivity problem"

# --- missing client tools altogether ---------------------------------------
rm -f "$BIN/psql" "$BIN/pg_dump" "$BIN/createdb" "$BIN/dropdb"
run
assert_status "$STATUS" 1 "missing postgres CLI tools exits 1"
assert_contains "$OUT" "psql" "names the missing CLI tool"

# --- never prints secret-ish values ----------------------------------------
case "$OUT" in
  *password*|*token*|*secret=*) printf 'FAIL - output must not contain credential values\n'
     ASSERT_FAILURES=$((ASSERT_FAILURES+1));;
  *) printf 'ok   - output contains no credential values\n';;
esac

# --- points at a teammate for things the repo cannot hold -------------------
assert_contains "$OUT" "teammate" "directs the user to a teammate for unstorable values"

# --- ver_cmp handles versions with missing components -----------------------
# ("21" must equal "21.0.0", not sort below it — an exclusive "< 21" ceiling depends on it)
eval "$(sed -n '/^ver_cmp()/,/^}/p' "$REPO/setup-doctor.sh")"
assert_equals "$(ver_cmp 21.0.0 21)"      "0"  "ver_cmp: 21.0.0 equals 21"
assert_equals "$(ver_cmp 17.9.1 20.11.0)" "-1" "ver_cmp: 17.9.1 is below 20.11.0"
assert_equals "$(ver_cmp 20.19.4 20.11.0)" "1" "ver_cmp: 20.19.4 is above 20.11.0"
assert_equals "$(ver_cmp 22.22.1 23)"     "-1" "ver_cmp: 22.22.1 is below 23"

done_tests
