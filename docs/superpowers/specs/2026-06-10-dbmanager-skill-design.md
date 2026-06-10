# dbmanager Skill — Design

**Date:** 2026-06-10
**Author:** Vincent Wu
**Status:** Approved for planning

## Problem

Managing several Guidewire Studio environments across multiple dev branches means
constantly backing up and restoring the local PostgreSQL databases (pcdb, bcdb,
cmdb) to match the branch being worked on, and launching the right Studio
environment with the correct IntelliJ + Java versions. Today this is done by hand
with shell scripts and shell aliases. The goal is a single, low-friction way to
drive these operations from within Claude Code.

## Solution Overview

A **project-local Claude Code skill** (`.claude/skills/dbmanager/`) that orchestrates
the existing scripts in this repo. It does **not** replace the scripts — it gathers
inputs, runs the correct script, summarizes results, and guards destructive actions.

Form factor was chosen over a desktop/web app because it requires no GUI build, lives
where the user already works, and is trivial to extend.

## Scope

In scope:
- List existing database backups.
- Create a new dated backup of the GW suite.
- Restore the GW suite (or a single DB) from a chosen backup.
- Launch a Studio environment with the correct IntelliJ + Java versions.

Out of scope (explicit decisions):
- Automatic matching of a backup version to a dev branch (backup and launch are
  independent operations).
- ClaimCenter database (ccdb) — backup/restore covers pcdb, bcdb, cmdb only, matching
  the existing scripts.
- Starting the Guidewire server inside an environment (still done manually in the IDE).

## Capabilities

### 1. List backups
Scans the repo's branch folders (e.g. `r10`, `r39`, `r43txho2adm`) for backup sets
named `MM-DD_{pcdb,bcdb,cmdb}.sql`. Presents each folder with its available dates,
file sizes, and age, so the user can see what is restorable at a glance. Folder names
are freeform and discovered at runtime — no hardcoded list.

### 2. Create backup
Runs `./backupgwsuite.sh <user> <folder>`.
- `<user>` defaults to `vincentwu`.
- `<folder>` is the user-named target (their branch label); defaults to `gw43` context
  when unspecified.
- Warns if a backup for today's date (`MM-DD`) already exists in that folder, because
  re-running overwrites it.

### 3. Restore (destructive — guarded)
The user picks a folder + date from the listing.
- Full suite: runs `./restoregwsuitebydate.sh <user> <folder>/<date>`.
- Single DB: runs `./restore.sh <user> <file> <dbname>`.

Because restore **drops and recreates** pcdb/bcdb/cmdb, the skill must:
1. Show exactly which databases will be dropped and which files will be restored.
2. Require an explicit user confirmation before executing.
3. Report any missing backup files instead of proceeding partially.

### 4. Launch Studio
A new helper script `launchstudio.sh <root> <center> [--ultimate]` exports
`IDEA_HOME` and `JAVA_HOME`, then runs `~/dev/bamboo/<root>/<center>/gwb studio`.

Behavior:
- **Branch roots are discovered dynamically** under `~/dev/bamboo/*`; centers are
  discovered from each root's subdirectories. A newly created root (e.g. `gw55`) works
  with no config change as long as `~/dev/bamboo/gw55/<center>/` exists.
- **Default context is `gw43`** when the user does not specify a root.
- `gw` and `gw-r1-tx` are snapshot-only environments and are **excluded as launch
  targets** (the user does not code in them).
- **Uniform version combo for all coding roots:**
  - Default IntelliJ: idea24 Community — `/Applications/IntelliJ_2024_1_5.app/Contents`
  - `--ultimate` IntelliJ: idea24U — `/Applications/IntelliJ_UT_2024_1_5.app/Contents`
  - Java: Java 21 — `/Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home`

Centers per known root (informational; discovery is dynamic):
- `gw43` → policycenter, billingcenter, contactmanager
- `gw35` → policycenter, claimcenter, billingcenter, contactmanager

### Launch config
IntelliJ and Java paths live in one editable place — `launch-config.sh` in the skill
directory (or a clearly delimited block in the helper script) — so version paths can
be updated without touching skill logic.

## Components

| Component | Responsibility | Depends on |
|---|---|---|
| `SKILL.md` | Routes user intent to a capability; defines trigger phrases; defines confirmation flow for restore | the scripts below |
| `backupgwsuite.sh` (existing) | Dump pcdb/bcdb/cmdb to a dated folder | pg_dump, local Postgres |
| `restoregwsuitebydate.sh` (existing) | Drop/create/restore all three DBs from a folder/date | psql, dropdb, createdb |
| `restore.sh` (existing) | Restore a single DB from a file | psql, dropdb, createdb |
| `launchstudio.sh` (new) | Export IDEA_HOME/JAVA_HOME and launch `gwb studio` | `~/dev/bamboo/<root>/<center>/gwb`, local IntelliJ/Java installs |
| `launch-config.sh` (new) | Holds IntelliJ + Java install paths | — |

## Data Flow

- **Backup:** user intent → skill resolves user + folder → `backupgwsuite.sh` →
  `.sql` files written into `<folder>/` → skill reports paths/sizes.
- **Restore:** user intent → skill lists folders/dates → user selects → skill shows
  drop/restore plan → user confirms → `restoregwsuitebydate.sh` (or `restore.sh`) →
  skill reports result.
- **Launch:** user intent → skill resolves root (default gw43) + center + edition →
  `launchstudio.sh` exports env → `gwb studio` launches.

## Error Handling

- Restore is gated behind an explicit confirmation showing the drop/restore plan.
- Missing backup files are reported; no partial silent restore.
- Same-date backup overwrite is warned before running.
- Nonexistent Studio path (`~/dev/bamboo/<root>/<center>/`) is reported rather than
  launched.
- Underlying tool failures (Postgres not running, permission errors) surface the
  script's own stderr.

## Invocation Examples

- "back up the gw suite to r43"
- "list backups"
- "restore r10 from 03-16"
- "restore just pcdb from r39 03-10"
- "launch policycenter studio for gw43"
- "launch billingcenter studio for gw35 ultimate"
