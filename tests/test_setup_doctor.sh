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
done
DIGITAL="$BAMBOO/gw"
mkdir -p "$DIGITAL/agentquotehome" "$DIGITAL/agentexperience"
for r in agentquotehome agentexperience; do
  mkdir -p "$DIGITAL/$r/node_modules"
  printf '20.11.0\n' > "$DIGITAL/$r/.nvmrc"
done
IDEA_CE="$FIX/idea-ce/Contents"; mkdir -p "$IDEA_CE"
JAVA="$FIX/jdk/Contents/Home"; mkdir -p "$JAVA/bin"

# Stub bin: psql/createdb/node/npm that behave like a healthy machine.
BIN="$FIX/bin"; mkdir -p "$BIN"
cat > "$BIN/psql" <<'PSQL'
#!/bin/bash
# -l lists databases; anything else is a connectivity probe that succeeds.
for a in "$@"; do
  case "$a" in
    -l|--list) printf 'pcdb\nbcdb\ncmdb\npostgres\n'; exit 0;;
  esac
done
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

assert_contains "$OUT" "node pin 20.11.0 satisfied" "matching .nvmrc pin passes"

# --- node version does not match the repo pin -------------------------------
printf '20.11.0\n' > "$DIGITAL/agentquotehome/.nvmrc"
printf '22.13.1\n' > "$DIGITAL/agentexperience/.nvmrc"
run
assert_status "$STATUS" 1 "node not matching a repo's .nvmrc pin exits 1"
assert_contains "$OUT" "pins node 22.13.1" "names the pinned version the repo wants"
assert_contains "$OUT" "nvm use" "suggests nvm use to fix the pin mismatch"
printf '20.11.0\n' > "$DIGITAL/agentexperience/.nvmrc"

# --- missing suite checkout -------------------------------------------------
mv "$BAMBOO/gw43/billingcenter" "$BAMBOO/gw43/.billingcenter-hidden"
run
assert_status "$STATUS" 1 "missing suite checkout exits 1"
assert_contains "$OUT" "billingcenter" "names the missing checkout"
mv "$BAMBOO/gw43/.billingcenter-hidden" "$BAMBOO/gw43/billingcenter"

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

done_tests
