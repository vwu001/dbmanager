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
DOCTOR_PG_EXTENSIONS="${DOCTOR_PG_EXTENSIONS:-postgis file_fdw pg_stat_statements pgcrypto unaccent}"

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

# --- helpers: which database the user chose, per center ---------------------
# A center runs on whichever <database> element has NO env= attribute; the env="h2mem"
# block is for gunit tests and the env="cloud-dev" one is for deployed environments, so
# both must be ignored, as must every commented-out block.
dbconfig_live() {  # <center_dir> -> config XML with comments stripped, newlines folded
  f="$1/modules/configuration/config/database-config.xml"
  [ -f "$f" ] || return 0
  perl -0777 -pe 's/<!--.*?-->//gs' "$f" 2>/dev/null | tr '\n' ' '
}

active_dbtype() {  # <center_dir> -> postgresql | h2 | (empty)
  dbconfig_live "$1" | grep -o '<database[^>]*>' | grep -v 'env=' \
    | sed -n 's/.*dbtype="\([a-z0-9]*\)".*/\1/p' | head -1
}

active_pg_field() {  # <center_dir> <db|user>
  u="$(dbconfig_live "$1" | grep -o 'jdbc:postgresql://[^"]*' | head -1)"
  [ -n "$u" ] || return 0
  case "$2" in
    db)   printf '%s' "$u" | sed -n 's|.*://[^/]*/\([^?]*\).*|\1|p' ;;
    user) printf '%s' "$u" | sed -n 's/.*[?&]user=\([^&"]*\).*/\1/p' ;;
  esac
}

# Collect the postgres-backed centers up front; the PostgreSQL checks only apply to them.
PG_CENTERS=""; PG_DBS=""; PG_ROLES=""; H2_CENTERS=""
for root in $DOCTOR_ROOTS; do
  for center in $DOCTOR_CENTERS; do
    cdir="$BAMBOO_ROOT/$root/$center"
    [ -d "$cdir" ] || continue
    t="$(active_dbtype "$cdir")"
    case "$t" in
      postgresql)
        PG_CENTERS="$PG_CENTERS $root/$center"
        d="$(active_pg_field "$cdir" db)";   [ -n "$d" ] && PG_DBS="$PG_DBS $d"
        u="$(active_pg_field "$cdir" user)"; [ -n "$u" ] && PG_ROLES="$PG_ROLES $u" ;;
      h2) H2_CENTERS="$H2_CENTERS $root/$center" ;;
    esac
  done
done

section "Database choice (from each center's database-config.xml)"
for c in $PG_CENTERS; do ok "$c -> PostgreSQL"; done
for c in $H2_CENTERS; do ok "$c -> H2 (no PostgreSQL needed)"; done
if [ -z "$PG_CENTERS$H2_CENTERS" ]; then
  warn "no database-config.xml found in the checkouts — cannot tell H2 from PostgreSQL"
fi

# --- 1. PostgreSQL ----------------------------------------------------------
section "PostgreSQL"
if [ -z "$PG_CENTERS" ]; then
  ok "skipped — no center is configured for PostgreSQL (H2 needs no server)"
fi
if [ -n "$PG_CENTERS" ]; then
pg_tools_ok=1
for t in psql pg_dump createdb dropdb; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t on PATH"
  else
    pg_tools_ok=0
    bad "$t not on PATH" "Install the PostgreSQL client tools (e.g. 'brew install postgresql@15') and reopen your shell."
  fi
done

pg_up=0
if [ "$pg_tools_ok" -eq 1 ]; then
  if psql -U "$DOCTOR_DB_USER" -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
    ok "PostgreSQL server reachable as role '$DOCTOR_DB_USER'"
    pg_up=1
  else
    bad "PostgreSQL server not reachable as role '$DOCTOR_DB_USER'" \
        "Start the server (e.g. 'brew services start postgresql@15') and confirm the role exists. Set DOCTOR_DB_USER=<role> if yours differs."
  fi
fi

if [ "$pg_up" -eq 1 ]; then
  # The suite runs SHOW lc_collate at startup; 16+ removed that parameter, so the server
  # dies with "unrecognized configuration parameter". A restore onto 16+ still succeeds,
  # which is why this has to be caught here rather than at startup.
  pgver="$(psql -U "$DOCTOR_DB_USER" -d postgres -tAc 'SHOW server_version_num;' 2>/dev/null | tr -dc '0-9')"
  if [ -n "$pgver" ]; then
    pgmajor=$((pgver / 10000))
    if [ "$pgmajor" -ge 16 ]; then
      bad "PostgreSQL $pgmajor server is not supported by the suite" \
          "The suite runs 'SHOW lc_collate' at startup, which PostgreSQL 16+ no longer has (no setting re-enables it). Run PostgreSQL 15 or older (in Postgres.app, add a 15 server; on Apple Silicon the v13 binaries need Rosetta)."
    else
      ok "PostgreSQL $pgmajor server (suite needs 15 or older)"
    fi
  else
    warn "could not read the PostgreSQL server version"
  fi

  dblist="$(psql -U "$DOCTOR_DB_USER" -l 2>/dev/null)"
  for db in $PG_DBS; do
    case "$dblist" in
      *"$db"*) ok "database $db exists" ;;
      *) bad "database $db missing" "createdb -U $DOCTOR_DB_USER $db   (then restore it: ./listbackups.sh to pick a set)" ;;
    esac
  done

  # The suite connects as its own login role (pcuser/bcuser/cmuser), not as the role that
  # owns the dumps. The dumps are full of "OWNER TO <role>", so these must exist BEFORE a
  # restore, or it fails thousands of times over.
  rolelist="$(psql -U "$DOCTOR_DB_USER" -d postgres -tAc 'SELECT rolname FROM pg_roles;' 2>/dev/null)"
  for r in $PG_ROLES postgres; do
    case " $(echo $rolelist) " in
      *" $r "*) ok "login role $r exists" ;;
      *) bad "login role $r missing" "psql -U $DOCTOR_DB_USER -d postgres -c \"CREATE ROLE $r LOGIN PASSWORD '<choose-one>';\"  (must exist before restoring a dump; ask a teammate if unsure what the suite expects)" ;;
    esac
  done

  # The dumps CREATE EXTENSION these; postgis in particular is a separate install.
  extlist="$(psql -U "$DOCTOR_DB_USER" -d postgres -tAc 'SELECT name FROM pg_available_extensions;' 2>/dev/null)"
  for e in $DOCTOR_PG_EXTENSIONS; do
    case " $(echo $extlist) " in
      *" $e "*) ok "extension $e available" ;;
      *) bad "extension $e not available" "The dumps CREATE EXTENSION $e and will fail without it. Install it (postgis ships separately: 'brew install postgis'; the rest come with the postgresql contrib package)." ;;
    esac
  done
else
  for db in $PG_DBS; do warn "database $db not checked (server unreachable)"; done
fi
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

# Compare dotted versions, tolerating missing components ("21" == "21.0.0").
# Echoes -1, 0 or 1 for a<b, a==b, a>b.
ver_cmp() {  # <a> <b>
  _va="$1"; _vb="$2"; _oifs="$IFS"; IFS=.
  set -- $_va; a1="${1:-0}"; a2="${2:-0}"; a3="${3:-0}"
  set -- $_vb; b1="${1:-0}"; b2="${2:-0}"; b3="${3:-0}"
  IFS="$_oifs"
  for pair in "$a1 $b1" "$a2 $b2" "$a3 $b3"; do
    x="${pair%% *}"; y="${pair##* }"
    case "$x$y" in ''|*[!0-9]*) continue ;; esac
    [ "$x" -lt "$y" ] && { echo -1; return; }
    [ "$x" -gt "$y" ] && { echo 1; return; }
  done
  echo 0
}

# The Node a human actually gets in that directory: their login shell may auto-switch on
# .nvmrc, so an agent's non-interactive PATH is NOT a reliable sample.
repo_node_version() {  # <dir>
  if [ -n "${DOCTOR_NODE_VERSION:-}" ]; then printf '%s' "$DOCTOR_NODE_VERSION"; return; fi
  v="$( cd "$1" 2>/dev/null && "${SHELL:-/bin/zsh}" -lic 'node -v' 2>/dev/null \
        | tr -d '\r' | grep -E '^v[0-9]' | tail -1 | sed 's/^v//' )"
  [ -z "$v" ] && v="$(node -v 2>/dev/null | sed 's/^v//')"
  printf '%s' "$v"
}

# engines.node from package.json, e.g. ">= 22.13.1 < 23" -> "22.13.1 23"
engines_range() {  # <dir>  -> "<min> <max_exclusive>" (either may be empty)
  [ -f "$1/package.json" ] || return 0
  raw="$(tr -d '\n' < "$1/package.json" \
         | sed 's/.*"engines"[^{]*{//; s/}.*//' \
         | sed 's/.*"node"[[:space:]]*:[[:space:]]*"//; s/".*//')"
  [ -n "$raw" ] || return 0
  min="$(printf '%s' "$raw" | sed -n 's/.*>=*[[:space:]]*\([0-9][0-9.]*\).*/\1/p')"
  max="$(printf '%s' "$raw" | sed -n 's/.*[^<>]<[[:space:]]*\([0-9][0-9.]*\).*/\1/p')"
  printf '%s %s' "$min" "$max"
}

command -v npm >/dev/null 2>&1 && ok "npm on PATH" \
  || bad "npm not on PATH" "Install Node (npm ships with it)."

for repo in $DOCTOR_DIGITAL_REPOS; do
  d="$DIGITAL_ROOT/$repo"
  if [ ! -d "$d" ]; then
    bad "$repo checkout missing" "Clone it to $d. Ask a teammate for the repo URL and the branch to track."
    continue
  fi

  active="$(repo_node_version "$d")"
  pin=""
  [ -f "$d/.nvmrc" ] && pin="$(tr -d ' \t\r\n' < "$d/.nvmrc")"
  set -- $(engines_range "$d"); emin="${1:-}"; emax="${2:-}"

  if [ -z "$active" ]; then
    bad "$repo: no node found" "Install Node via nvm; this repo pins ${pin:-a version} in .nvmrc."
  elif [ -n "$emin" ] && [ "$(ver_cmp "$active" "$emin")" -lt 0 ]; then
    bad "$repo: node $active is below the required $emin" \
        "cd $d && nvm use    (install first if needed: nvm install ${pin:-$emin})"
  elif [ -n "$emax" ] && [ "$(ver_cmp "$active" "$emax")" -ge 0 ]; then
    bad "$repo: node $active is at or above the unsupported $emax" \
        "cd $d && nvm use    (install first if needed: nvm install ${pin:-$emin})"
  elif [ -n "$pin" ] && [ "$pin" != "$active" ]; then
    ok "$repo: node $active satisfies engines (.nvmrc pins $pin — in range, so fine)"
  else
    ok "$repo: node $active satisfies the version requirement"
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
