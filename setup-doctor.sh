#!/bin/bash
# Preflight for a fresh machine: check that everything the suite + digital apps need is
# present BEFORE walking through the guided setup docs.
#
# Usage: ./setup-doctor.sh [root ...]      (roots default to $DOCTOR_ROOTS, else gw43)
#
# Reports ok / warn / FAIL per check and prints a remediation hint for each failure.
# NEVER prints the value of any credential or environment variable.
# Exit 0 when every required check passes, 1 otherwise.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/launch-config.sh"

DIGITAL_ROOT="${DIGITAL_ROOT:-$BAMBOO_ROOT/gw}"
DOCTOR_ROOTS="${DOCTOR_ROOTS:-gw43}"
DOCTOR_CENTERS="${DOCTOR_CENTERS:-policycenter billingcenter contactmanager}"
DOCTOR_DBS="${DOCTOR_DBS:-pcdb bcdb cmdb}"
DOCTOR_DIGITAL_REPOS="${DOCTOR_DIGITAL_REPOS:-agentquotehome agentexperience}"
DOCTOR_DB_USER="${DOCTOR_DB_USER:-${USER:-vincentwu}}"
DOCTOR_SKIP_ENV="${DOCTOR_SKIP_ENV:-0}"

[ $# -gt 0 ] && DOCTOR_ROOTS="$*"

FAILED=0
HINTS=""

ok()   { printf '[ ok ] %s\n' "$1"; }
warn() { printf '[warn] %s\n' "$1"; }
bad()  {  # bad <label> <hint>
  printf '[FAIL] %s\n' "$1"
  FAILED=$((FAILED + 1))
  HINTS="$HINTS
  - $1
      $2"
}

section() { printf '\n== %s ==\n' "$1"; }

# --- 1. PostgreSQL ----------------------------------------------------------
section "PostgreSQL"
pg_tools_ok=1
for t in psql pg_dump createdb dropdb; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t on PATH"
  else
    pg_tools_ok=0
    bad "$t not on PATH" "Install the PostgreSQL client tools (e.g. 'brew install postgresql@16') and reopen your shell."
  fi
done

pg_up=0
if [ "$pg_tools_ok" -eq 1 ]; then
  if psql -U "$DOCTOR_DB_USER" -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
    ok "PostgreSQL server reachable as role '$DOCTOR_DB_USER'"
    pg_up=1
  else
    bad "PostgreSQL server not reachable as role '$DOCTOR_DB_USER'" \
        "Start the server (e.g. 'brew services start postgresql@16') and confirm the role exists. Set DOCTOR_DB_USER=<role> if yours differs."
  fi
fi

if [ "$pg_up" -eq 1 ]; then
  dblist="$(psql -U "$DOCTOR_DB_USER" -l 2>/dev/null)"
  for db in $DOCTOR_DBS; do
    case "$dblist" in
      *"$db"*) ok "database $db exists" ;;
      *) bad "database $db missing" "createdb -U $DOCTOR_DB_USER $db   (then restore it: ./listbackups.sh to pick a set)" ;;
    esac
  done
else
  for db in $DOCTOR_DBS; do warn "database $db not checked (server unreachable)"; done
fi

# --- 2. Studio toolchain ----------------------------------------------------
section "Studio toolchain"
if [ -d "$IDEA_CE_HOME" ]; then
  ok "IntelliJ Community at $IDEA_CE_HOME"
else
  bad "IntelliJ Community missing at $IDEA_CE_HOME" \
      "Install IntelliJ 2024.1.5 Community, or point IDEA_CE_HOME at your install in launch-config.sh."
fi
if [ -d "$IDEA_UT_HOME" ]; then
  ok "IntelliJ Ultimate at $IDEA_UT_HOME"
else
  warn "IntelliJ Ultimate absent at $IDEA_UT_HOME (optional — only needed for --ultimate)"
fi
if [ -d "$STUDIO_JAVA_HOME" ]; then
  ok "Java at $STUDIO_JAVA_HOME"
else
  bad "Java missing at $STUDIO_JAVA_HOME" \
      "Install Amazon Corretto 21, or point STUDIO_JAVA_HOME at your JDK in launch-config.sh."
fi

# --- 3. Suite checkouts -----------------------------------------------------
section "Suite checkouts"
for root in $DOCTOR_ROOTS; do
  for center in $DOCTOR_CENTERS; do
    d="$BAMBOO_ROOT/$root/$center"
    if [ ! -d "$d" ]; then
      bad "$root/$center checkout missing" \
          "Clone it to $d. Ask a teammate which repo and branch this root should track."
    elif [ ! -x "$d/gwb" ]; then
      bad "$root/$center has no executable gwb" "Check the clone completed, then: chmod +x $d/gwb"
    else
      ok "$root/$center checkout present"
    fi
  done
done

# --- 4. Node + digital repos ------------------------------------------------
section "Digital UI"
active_node=""
if command -v node >/dev/null 2>&1; then
  active_node="$(node -v 2>/dev/null | sed 's/^v//')"
  ok "node $active_node active"
else
  bad "node not on PATH" "Install Node via nvm; each digital repo pins its version in .nvmrc."
fi
command -v npm >/dev/null 2>&1 && ok "npm on PATH" \
  || bad "npm not on PATH" "Install Node (npm ships with it)."

for repo in $DOCTOR_DIGITAL_REPOS; do
  d="$DIGITAL_ROOT/$repo"
  if [ ! -d "$d" ]; then
    bad "$repo checkout missing" "Clone it to $d. Ask a teammate for the repo URL and the branch to track."
    continue
  fi

  # The repo pins its own Node version; honour that over any global guess.
  want=""
  [ -f "$d/.nvmrc" ] && want="$(tr -d ' \t\r\n' < "$d/.nvmrc")"
  if [ -n "$want" ] && [ -n "$active_node" ] && [ "$want" != "$active_node" ]; then
    bad "$repo pins node $want but $active_node is active" \
        "cd $d && nvm use    (install it first if needed: nvm install $want)"
  elif [ -n "$want" ]; then
    ok "$repo node pin $want satisfied"
  fi

  if [ ! -d "$d/node_modules" ]; then
    warn "$repo present but node_modules absent — run 'npm install' in $d"
  else
    ok "$repo checkout present (node_modules installed)"
  fi
done

# --- 5. Environment variables ----------------------------------------------
section "Environment variables"
if [ "$DOCTOR_SKIP_ENV" = "1" ]; then
  warn "env-var check skipped (DOCTOR_SKIP_ENV=1)"
elif [ -x "$DIR/localconfig-checkenv.sh" ]; then
  if "$DIR/localconfig-checkenv.sh"; then
    ok "required suite env vars are set"
  else
    bad "required suite env vars are missing (see the report above)" \
        "Set the [set] vars yourself; for any [req]/[opt] value you do not have, ask a teammate — they are never stored in this repo."
  fi
else
  warn "localconfig-checkenv.sh not executable — skipping env check (chmod +x it)"
fi

# --- summary ----------------------------------------------------------------
printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'All required checks passed.\n'
  printf 'Next: follow the guided setup in .claude/skills/dbmanager/onboarding.md\n'
  printf 'Anything it cannot give you (registry auth, integration keys, workset GUID,\n'
  printf 'test logins) is deliberately not in this repo — ask a teammate for those.\n'
  exit 0
fi

printf '%s check(s) failed:\n%s\n\n' "$FAILED" "$HINTS"
printf 'Fix the above, then re-run ./setup-doctor.sh.\n'
printf 'For anything you cannot obtain yourself, ask a teammate — this repo deliberately\n'
printf 'stores no credentials or internal values.\n'
exit 1
