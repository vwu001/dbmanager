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
5. Report success/failure from the script output. The full-suite script restores each
   DB independently and only prints `Backup file ... not found!` for a missing one — it
   does NOT stop. So if any file is reported missing, warn the user the suite is now at
   mismatched versions (some DBs restored, some not) and help them re-run or fix it.

## 4. Launch Studio

Run `./launchstudio.sh <root> <center> [--ultimate]`.
- `<root>` is a branch root under `~/dev/bamboo` (e.g. `gw43`, `gw35`, or a new one the
  user names). Default to `gw43`. `gw` and `gw-r1-tx` are snapshot-only and are rejected.
- `<center>` is `policycenter`, `billingcenter`, `contactmanager`, or `claimcenter`.
- Add `--ultimate` only if the user asks for the Ultimate IDE; otherwise Community + Java 21
  are used by default.
- To preview without launching, prefix with `DRY_RUN=1`.
- If the script reports `... gwb not found or not executable`, tell the user which
  `~/dev/bamboo/<root>/<center>` directory (or its `gwb` binary) is missing rather than retrying.

Version paths live in `launch-config.sh`; edit there if IntelliJ/Java versions change.

## 5. Local config (localconfig)

Each suite checkout needs local edits to tracked files to run with `-Denv=local`
(`config.local.properties`, `database-config.xml`, `credentials.xml`, a few
`plugin/registry/*.gwp`). These are the files the user otherwise shelves/unshelves.
**No suite config is ever committed to this repo** — secrets and internal values live only
in the user's suite and in gitignored backups.

### Setup a fresh checkout (guided — no stored copies)
When the user has no backup yet, WALK THEM THROUGH editing the base files by following
`localconfig-setup.md` (in this skill directory) step by step. Apply the non-secret edits
yourself; STOP and ask the user to paste their own keys where that doc marks
`<YOUR_...>` / `REPLACE_ME` (credentials, DB password, integration URLs). Never invent or
commit secret values.

### Back up (local only, never committed)
`./localconfig-backup.sh <root> <center>` → captures the modified localconfig (incl. the
real `credentials.xml`) into gitignored `localconfig/backups/<root>/<center>/`. Use this
before/after risky git work, or to snapshot a working setup. Selection is git-diff-based
(only files differing from HEAD), so it ignores unmodified files and code work
(`.gs`, `all.js`); paths come from `localconfig/manifest.txt`.

### Restore
`./localconfig-restore.sh <root> <center>` → copies the local backup back into the suite.
Errors if no backup exists. After the first guided setup + backup, this is the fast path
for future fresh checkouts.

Secrets rule: the real `credentials.xml` lives ONLY in the suite and in gitignored
`localconfig/backups/`. Never commit it. This is pure backup/restore — it does not touch
the git index (no skip-worktree), so the user can still shelve/unshelve manually in their
own repo when they choose.
