# dbmanager Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a project-local Claude Code skill that orchestrates the repo's GW-suite DB backup/restore scripts and launches Studio environments with the correct IntelliJ + Java versions.

**Architecture:** Two new POSIX/bash-3.2-compatible helper scripts (`listbackups.sh`, `launchstudio.sh`) plus an editable config (`launch-config.sh`) live in the repo root alongside the existing scripts. A skill instruction file (`.claude/skills/dbmanager/SKILL.md`) routes user intent to the right script and enforces a confirmation gate before destructive restores. Helper scripts support a dry-run / fixture-root mode so they are unit-testable without touching real databases or Studio installs.

**Tech Stack:** Bash 3.2 (macOS default), PostgreSQL CLI tools (`pg_dump`, `psql`, `dropdb`, `createdb`) via existing scripts, Claude Code project skill.

---

## File Structure

- Create: `launch-config.sh` — editable IntelliJ/Java/bamboo-root install paths; all overridable via env for testing.
- Create: `launchstudio.sh` — resolve env + validate path + launch `gwb studio`; `DRY_RUN=1` prints resolved env/command instead of executing.
- Create: `listbackups.sh` — scan branch folders for `MM-DD_pcdb.sql` sets and print folder/date/size; `LISTBACKUPS_ROOT` overridable for testing.
- Create: `.claude/skills/dbmanager/SKILL.md` — skill instructions, trigger phrases, restore confirmation gate.
- Create: `tests/assert.sh` — tiny shared assertion helper.
- Create: `tests/test_launchstudio.sh` — behavior tests for `launchstudio.sh`.
- Create: `tests/test_listbackups.sh` — behavior tests for `listbackups.sh`.

Existing scripts (`backupgwsuite.sh`, `restoregwsuitebydate.sh`, `restore.sh`) are reused unchanged.

---

### Task 1: Shared test assertion helper

**Files:**
- Create: `tests/assert.sh`

- [ ] **Step 1: Create the assertion helper**

```bash
#!/bin/bash
# Minimal assertion helpers for plain-bash tests.
# Usage: source tests/assert.sh ; then call assert_* ; call done_tests at end.

ASSERT_FAILURES=0

assert_contains() {
  # assert_contains "<haystack>" "<needle>" "<message>"
  case "$1" in
    *"$2"*) printf 'ok   - %s\n' "$3" ;;
    *) printf 'FAIL - %s\n      expected to contain: %s\n      got: %s\n' "$3" "$2" "$1"
       ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
  esac
}

assert_equals() {
  # assert_equals "<actual>" "<expected>" "<message>"
  if [ "$1" = "$2" ]; then
    printf 'ok   - %s\n' "$3"
  else
    printf 'FAIL - %s\n      expected: %s\n      got: %s\n' "$3" "$2" "$1"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

assert_status() {
  # assert_status "<actual_exit_code>" "<expected_exit_code>" "<message>"
  if [ "$1" -eq "$2" ]; then
    printf 'ok   - %s\n' "$3"
  else
    printf 'FAIL - %s\n      expected exit %s, got %s\n' "$3" "$2" "$1"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

done_tests() {
  if [ "$ASSERT_FAILURES" -eq 0 ]; then
    printf '\nAll assertions passed.\n'
    exit 0
  fi
  printf '\n%s assertion(s) failed.\n' "$ASSERT_FAILURES"
  exit 1
}
```

- [ ] **Step 2: Commit**

```bash
git add tests/assert.sh
git commit -m "test: add shared bash assertion helper"
```

---

### Task 2: `launch-config.sh` and `launchstudio.sh`

**Files:**
- Create: `launch-config.sh`
- Create: `launchstudio.sh`
- Test: `tests/test_launchstudio.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_launchstudio.sh`:

```bash
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

done_tests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_launchstudio.sh`
Expected: FAIL — `launchstudio.sh` does not exist yet (`No such file or directory`).

- [ ] **Step 3: Create `launch-config.sh`**

```bash
#!/bin/bash
# Editable install paths for launching Studio. Update here if versions change.
# Every value is overridable via environment (used by tests).

IDEA_CE_HOME="${IDEA_CE_HOME:-/Applications/IntelliJ_2024_1_5.app/Contents}"
IDEA_UT_HOME="${IDEA_UT_HOME:-/Applications/IntelliJ_UT_2024_1_5.app/Contents}"
STUDIO_JAVA_HOME="${STUDIO_JAVA_HOME:-/Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home}"
BAMBOO_ROOT="${BAMBOO_ROOT:-${HOME}/dev/bamboo}"

# Snapshot-only roots that must NOT be launched (space-separated).
EXCLUDED_ROOTS="${EXCLUDED_ROOTS:-gw gw-r1-tx}"
```

- [ ] **Step 4: Create `launchstudio.sh`**

```bash
#!/bin/bash
# Launch a Guidewire Studio environment with the correct IntelliJ + Java.
# Usage: ./launchstudio.sh <root> <center> [--ultimate]
# Set DRY_RUN=1 to print the resolved environment and command without launching.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/launch-config.sh"

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "Usage: $0 <root> <center> [--ultimate]" >&2
  exit 1
fi

root="$1"
center="$2"
edition="${3:-}"

for excluded in $EXCLUDED_ROOTS; do
  if [ "$root" = "$excluded" ]; then
    echo "Error: '$root' is snapshot-only and is not a launch target." >&2
    exit 1
  fi
done

if [ "$edition" = "--ultimate" ]; then
  idea_home="$IDEA_UT_HOME"
elif [ -z "$edition" ]; then
  idea_home="$IDEA_CE_HOME"
else
  echo "Error: unknown option '$edition' (expected --ultimate)." >&2
  exit 1
fi

studio_dir="${BAMBOO_ROOT}/${root}/${center}"
if [ ! -x "${studio_dir}/gwb" ]; then
  echo "Error: ${studio_dir}/gwb not found or not executable." >&2
  exit 1
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "IDEA_HOME=${idea_home}"
  echo "JAVA_HOME=${STUDIO_JAVA_HOME}"
  echo "CMD=${studio_dir}/gwb studio"
  exit 0
fi

export IDEA_HOME="$idea_home"
export JAVA_HOME="$STUDIO_JAVA_HOME"
cd "$studio_dir" || exit 1
exec ./gwb studio
```

- [ ] **Step 5: Make scripts executable**

```bash
chmod +x launchstudio.sh launch-config.sh
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bash tests/test_launchstudio.sh`
Expected: PASS — `All assertions passed.`

- [ ] **Step 7: Commit**

```bash
git add launch-config.sh launchstudio.sh tests/test_launchstudio.sh
git commit -m "feat: add launchstudio.sh with version config and dry-run tests"
```

---

### Task 3: `listbackups.sh`

**Files:**
- Create: `listbackups.sh`
- Test: `tests/test_listbackups.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_listbackups.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_listbackups.sh`
Expected: FAIL — `listbackups.sh` does not exist yet.

- [ ] **Step 3: Create `listbackups.sh`**

```bash
#!/bin/bash
# List GW-suite database backup sets found in branch folders.
# Usage: ./listbackups.sh [folder]
#   (no arg) scan every immediate subfolder of the repo
#   <folder> scan only that folder
# A backup set is identified by a "MM-DD_pcdb.sql" file in a folder.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${LISTBACKUPS_ROOT:-$SCRIPT_DIR}"

target="${1:-}"

if [ -n "$target" ]; then
  search_dirs="${ROOT}/${target}"
else
  search_dirs="$(find "$ROOT" -maxdepth 1 -mindepth 1 -type d)"
fi

found=0
for dir in $search_dirs; do
  [ -d "$dir" ] || continue
  folder="$(basename "$dir")"
  for f in "$dir"/*_pcdb.sql; do
    [ -e "$f" ] || continue
    found=1
    base="$(basename "$f")"
    date="${base%_pcdb.sql}"
    size="$(du -h "$f" | cut -f1)"
    echo "${folder}/${date}  (pcdb ${size})"
  done
done

if [ "$found" -eq 0 ]; then
  echo "No backups found."
fi
```

- [ ] **Step 4: Make executable**

```bash
chmod +x listbackups.sh
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_listbackups.sh`
Expected: PASS — `All assertions passed.`

- [ ] **Step 6: Commit**

```bash
git add listbackups.sh tests/test_listbackups.sh
git commit -m "feat: add listbackups.sh with fixture-root tests"
```

---

### Task 4: `dbmanager` skill instructions

**Files:**
- Create: `.claude/skills/dbmanager/SKILL.md`

- [ ] **Step 1: Create the skill file**

```markdown
---
name: dbmanager
description: Use to back up, restore, and inspect the local Guidewire suite PostgreSQL databases (pcdb, bcdb, cmdb), and to launch Studio environments with the correct IntelliJ + Java versions. Trigger on "back up the gw suite", "list backups", "restore <folder> from <date>", "restore pcdb", "launch <center> studio for <root>", or any request to back up / restore the GW databases or open a Studio environment. Operates on this repo's scripts and backup folders.
---

# dbmanager

Orchestrates the DB backup/restore scripts and Studio launcher in this repo. Run all
commands from the repo root. The Postgres username defaults to `vincentwu` unless the
user says otherwise. Default branch context is `gw43` when the user does not specify.

## 1. List backups

Run `./listbackups.sh` (optionally `./listbackups.sh <folder>`) and present the output.
Each line is `<folder>/<date>  (pcdb <size>)`. Use this to help the user choose a
restore source.

## 2. Create a backup

Run `./backupgwsuite.sh <user> <folder>`.
- `<folder>` is the user's branch label (e.g. `r43`, `gw55`). Default to `gw43` if unspecified.
- Before running, check whether today's date (`date +%m-%d`) already has a set in that
  folder via `./listbackups.sh <folder>`. If it does, warn that re-running overwrites
  today's files and confirm before proceeding.

## 3. Restore (DESTRUCTIVE — always confirm)

Restoring DROPS and recreates pcdb, bcdb, and cmdb. NEVER run a restore without an
explicit confirmation in this turn.

Flow:
1. Run `./listbackups.sh` (or for one folder) and show the available folder/date sets.
2. State exactly what will happen: "This will DROP and recreate pcdb, bcdb, cmdb and
   restore them from `<folder>/<date>`." For a single-DB restore, name only that DB.
3. Wait for the user to explicitly confirm.
4. Then run:
   - Full suite: `./restoregwsuitebydate.sh <user> <folder>/<date>`
   - Single DB: `./restore.sh <user> <folder>/<date>_<db>.sql <db>` (db = pcdb|bcdb|cmdb)
5. Report success/failure from the script output. If a backup file is missing, report it
   and do not continue.

## 4. Launch Studio

Run `./launchstudio.sh <root> <center> [--ultimate]`.
- `<root>` is a branch root under `~/dev/bamboo` (e.g. `gw43`, `gw35`, or a new one the
  user names). Default to `gw43`. `gw` and `gw-r1-tx` are snapshot-only and are rejected.
- `<center>` is `policycenter`, `billingcenter`, `contactmanager`, or `claimcenter`.
- Add `--ultimate` only if the user asks for the Ultimate IDE; otherwise Community + Java 21
  are used by default.
- To preview without launching, prefix with `DRY_RUN=1`.
- If the script reports the path is not found, tell the user which `~/dev/bamboo/<root>/<center>`
  directory is missing rather than retrying.

Version paths live in `launch-config.sh`; edit there if IntelliJ/Java versions change.
```

- [ ] **Step 2: Verify the skill is discoverable and scripts resolve**

Run:
```bash
test -f .claude/skills/dbmanager/SKILL.md && echo "SKILL present"
head -3 .claude/skills/dbmanager/SKILL.md
ls launchstudio.sh listbackups.sh launch-config.sh
```
Expected: `SKILL present`, the YAML frontmatter shows, and all three scripts are listed.

- [ ] **Step 3: Smoke-test the launcher against a real root (dry run)**

Run: `DRY_RUN=1 ./launchstudio.sh gw43 policycenter`
Expected: prints `IDEA_HOME=...IntelliJ_2024_1_5...`, `JAVA_HOME=...corretto-21...`, and
`CMD=.../gw43/policycenter/gwb studio` — confirming the real path exists. (If gw43/policycenter
has no `gwb`, this reports "not found" — note it but it is environment-specific, not a code bug.)

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/dbmanager/SKILL.md
git commit -m "feat: add dbmanager skill orchestrating backup/restore/launch"
```

---

## Self-Review

**Spec coverage:**
- List backups → Task 3 (`listbackups.sh`) + SKILL §1. ✓
- Create backup (default user/folder, overwrite warning) → SKILL §2 (reuses `backupgwsuite.sh`). ✓
- Restore with confirmation gate + single-DB → SKILL §3 (reuses `restoregwsuitebydate.sh` / `restore.sh`). ✓
- Launch Studio (dynamic roots, default gw43, exclude gw/gw-r1-tx, uniform idea24 CE/UT + Java 21) → Task 2 (`launchstudio.sh` + `launch-config.sh`) + SKILL §4. ✓
- Config in one editable place → `launch-config.sh`. ✓
- Out of scope (ccdb, branch-version matching, GW server start) → not implemented, correct. ✓

**Placeholder scan:** No TBD/TODO; every code step contains full content. ✓

**Type/name consistency:** Env var names (`IDEA_CE_HOME`, `IDEA_UT_HOME`, `STUDIO_JAVA_HOME`, `BAMBOO_ROOT`, `EXCLUDED_ROOTS`, `LISTBACKUPS_ROOT`, `DRY_RUN`) and script names (`launchstudio.sh`, `listbackups.sh`, `launch-config.sh`) are used identically across config, scripts, tests, and SKILL.md. Restore commands in SKILL.md match the existing scripts' argument order (`<user> <folder>/<date>` and `<user> <file> <db>`). ✓
