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
