# dbmanager

Personal tooling to manage local Guidewire suite environments across multiple dev
branches:

- **Databases** — back up / restore the local PostgreSQL databases (PolicyCenter,
  BillingCenter, ContactManager).
- **Studio** — launch with the correct IntelliJ + Java versions.
- **Suite local config** — guided setup of a checkout's `localconfig` (the local edits
  needed to run with `-Denv=local`), plus local backup/restore and an env-var check.
- **Digital UI (Jutro)** — guided setup, local backup/restore, and ordered start of the
  `agentquotehome` / `agentexperience` apps.

Everything is plain `bash` plus a [Claude Code skill](.claude/skills/dbmanager/SKILL.md)
that orchestrates the scripts conversationally.

**Nothing sensitive is committed.** Suite/digital config (credentials, `.npmrc` tokens,
internal URLs) lives only in your checkouts and in **gitignored** local backups
(`localconfig/backups/`, `digital/backups/`). Setup uses guided in-place edits with
placeholders, never committed copies.

## Layout

| File | Purpose |
|------|---------|
| [`backupgwsuite.sh`](backupgwsuite.sh) | Dump `pcdb`, `bcdb`, `cmdb` into a dated, branch-named folder |
| [`restoregwsuitebydate.sh`](restoregwsuitebydate.sh) | Drop/recreate and restore all three DBs from a folder/date |
| [`restore.sh`](restore.sh) | Restore a single DB from a `.sql` file |
| [`listbackups.sh`](listbackups.sh) | List available backup sets per branch folder |
| [`setup-doctor.sh`](setup-doctor.sh) | Preflight a machine: database choice, PostgreSQL roles/extensions, IDE + Java, checkouts, Node pins, env vars |
| [`launchstudio.sh`](launchstudio.sh) | Launch a Studio env with the right `IDEA_HOME` / `JAVA_HOME` |
| [`launch-config.sh`](launch-config.sh) | Editable IntelliJ / Java / bamboo-root paths |
| [`drop_database.sh`](drop_database.sh) | Drop `pcdb`/`bcdb`/`cmdb` |
| [`drop_database_exceptlist.sh`](drop_database_exceptlist.sh) | Drop all DBs except an allowlist |
| [`localconfig-backup.sh`](localconfig-backup.sh) / [`localconfig-restore.sh`](localconfig-restore.sh) | Back up / restore a suite checkout's localconfig to gitignored `localconfig/backups/` |
| [`localconfig-checkenv.sh`](localconfig-checkenv.sh) | Report which suite env vars are set vs missing (values masked) |
| [`localconfig-lib.sh`](localconfig-lib.sh) / [`localconfig/manifest.txt`](localconfig/manifest.txt) | Shared helpers + the localconfig file list |
| [`digital-backup.sh`](digital-backup.sh) / [`digital-restore.sh`](digital-restore.sh) | Back up / restore a Jutro app's config (`.env`, `.npmrc`, `config.json`) to gitignored `digital/backups/` |
| [`digital-start.sh`](digital-start.sh) | Start the Jutro apps in order (agentquotehome → agentexperience) |
| [`digital-lib.sh`](digital-lib.sh) / [`digital/manifest.txt`](digital/manifest.txt) | Shared helpers + the digital config file list |
| [`tests/`](tests/) | Plain-bash tests for `launchstudio.sh`, `listbackups.sh`, `setup-doctor.sh` and the localconfig manifest |
| [`.claude/skills/dbmanager/`](.claude/skills/dbmanager/) | Claude Code skill that drives the above, plus the guided docs: `onboarding.md` (ordered build-out), `localconfig-setup.md`, `studio-setup.md`, `digital-setup.md` |

Backups live in branch-named folders (e.g. `r10/`, `r39/`, `r43txho2adm/`) as
`MM-DD_pcdb.sql`, `MM-DD_bcdb.sql`, `MM-DD_cmdb.sql`. The `.sql` files are gitignored.

## Prerequisites

- **If you run the suite on PostgreSQL** (the alternative is H2 — see "Setting up a new
  machine"): CLI tools (`pg_dump`, `psql`, `dropdb`, `createdb`) on `PATH` and the server
  running; a role that can create/drop the databases (examples use `vincentwu`); the
  `pcuser`/`bcuser`/`cmuser` login roles the suite connects as, which must exist *before*
  any restore; and the extensions the dumps create — `postgis` (a separate install),
  `file_fdw`, `pg_stat_statements`, `pgcrypto`, `unaccent`.
- IntelliJ IDEA installs and Amazon Corretto JDK at the paths in
  [`launch-config.sh`](launch-config.sh) (defaults: IntelliJ 2024.1.5 CE/UT, Corretto 21).
- Guidewire checkouts under `~/dev/bamboo/<root>/<center>/` (e.g. `gw43/policycenter`).

Make the scripts executable once: `chmod +x *.sh`.

Run `./setup-doctor.sh` to check all of the above at once (see below).

## Setting up a new machine

```bash
./setup-doctor.sh            # preflight: what's missing and how to fix it
./setup-doctor.sh gw43 gw35  # check specific suite roots
```

Reads each center's `database-config.xml` to see whether you chose H2 or PostgreSQL, and
checks only what that choice needs — on PostgreSQL that includes the login roles the suite
connects as and the extensions the dumps create. Also checks IntelliJ + Java at the
[`launch-config.sh`](launch-config.sh) paths, suite checkouts, Node against each digital
repo's `.nvmrc` pin, and required env vars. Prints a remediation hint per failure and
never prints the value of any credential or env var. Exits non-zero while anything
required is missing.

Starting the suite is a Studio job for day-to-day work — the run configurations are
gitignored in every center, so each developer builds their own. Per-center flags:
`-Dgw.pc.env=local` (:8180), `-Dgw.bc.env=local` (:8580), `-Dgw.ab.env=local` (:8280 —
ContactManager is **ab**, not cm). `./gwb runServer` from the center directory is the
alternative. Details in
[`studio-setup.md`](.claude/skills/dbmanager/studio-setup.md).

Then follow the ordered build-out in
[`.claude/skills/dbmanager/onboarding.md`](.claude/skills/dbmanager/onboarding.md):
clone → choose H2 or PostgreSQL → preflight → localconfig → start the suite in Studio →
digital → snapshot. Studio run configurations are covered in
[`studio-setup.md`](.claude/skills/dbmanager/studio-setup.md).

This repo is public and holds **no credentials and no internal values**. The guided setup
docs mark every such point **ASK A TEAMMATE** — the registry auth token, integration keys,
internal endpoint URLs, the APD workset GUID, `DEPLOYMENT_ID`, and the local test login
all have to come from someone on the team.

## Usage

### List backups
```bash
./listbackups.sh            # every branch folder
./listbackups.sh r43txho2adm  # one folder
```

### Create a backup
```bash
./backupgwsuite.sh <pg-user> <folder>
# e.g. ./backupgwsuite.sh vincentwu r43txho2adm
```
Writes `MM-DD_{pcdb,bcdb,cmdb}.sql` into `<folder>/`. Re-running on the same day
overwrites that day's files.

### Restore (destructive)
Restoring **drops and recreates** `pcdb`, `bcdb`, `cmdb`.
```bash
# Full suite from a folder/date
./restoregwsuitebydate.sh <pg-user> <folder>/<MM-DD>
# e.g. ./restoregwsuitebydate.sh vincentwu r10/03-16

# Single DB
./restore.sh <pg-user> <folder>/<MM-DD>_<db>.sql <db>
# e.g. ./restore.sh vincentwu r39/03-10_pcdb.sql pcdb
```
> Note: `restoregwsuitebydate.sh` restores each DB independently. If one `.sql` file is
> missing it prints a warning and continues — leaving the suite at mismatched versions.
> Check all three if you see a "not found" message.

### Launch Studio
```bash
./launchstudio.sh <root> <center> [--ultimate]
# e.g. ./launchstudio.sh gw43 policycenter
#      ./launchstudio.sh gw35 billingcenter --ultimate
DRY_RUN=1 ./launchstudio.sh gw43 policycenter   # preview env + command, no launch
```
- `<root>` is a branch root under `~/dev/bamboo` (e.g. `gw43`, `gw35`). `gw` and
  `gw-r1-tx` are snapshot-only and rejected.
- `<center>` is `policycenter`, `billingcenter`, `contactmanager`, or `claimcenter`.
- Defaults to IntelliJ Community + Java 21; `--ultimate` switches to the Ultimate IDE.

### Suite local config (localconfig)

A suite checkout needs local edits to tracked files to run with `-Dgw.<xx>.env=local`
(`config.local.properties`, `database-config.xml`, `credentials.xml`, a few
`plugin/registry/*.gwp`, and any integration `.gs` overrides). These are the files you'd
otherwise shelve/unshelve.

```bash
# Back up the current localconfig (incl. real credentials) -> gitignored local store
./localconfig-backup.sh <root> <center>     # e.g. ./localconfig-backup.sh gw43 policycenter

# Restore it back into the checkout
./localconfig-restore.sh <root> <center>

# Report which required env vars are set vs missing (values never printed)
./localconfig-checkenv.sh
```

Selection is git-diff-based (only files modified from `HEAD` under
[`localconfig/manifest.txt`](localconfig/manifest.txt)), so it ignores unmodified files and
generated output. Integration `.gs` overrides under
`modules/configuration/gsrc/bamboo/integration` **are** captured — see
[`localconfig-setup.md`](.claude/skills/dbmanager/localconfig-setup.md) §5 for how to make
them; feature work in `.gs` files elsewhere is not. For a **fresh checkout with no backup**, the skill walks you through
editing the base files via [`.claude/skills/dbmanager/localconfig-setup.md`](.claude/skills/dbmanager/localconfig-setup.md)
(you paste your own keys; nothing committed).

### Digital UI (Jutro apps)

Two Jutro apps under `~/dev/bamboo/gw/` run the agent UI against a running local suite:
`agentquotehome` (`:3001`) and `agentexperience` (`:3000`).

```bash
# Back up / restore a repo's config (.env, .npmrc, src/config/config.json) -> gitignored
./digital-backup.sh <repo>      # repo = agentquotehome | agentexperience
./digital-restore.sh <repo>

# Start both in the correct order (PolicyCenter must be running first)
./digital-start.sh
```

`digital-start.sh` starts **agentquotehome first**, waits for `:3001`, then
**agentexperience** (`:3000`), backgrounded with logs in gitignored `digital/logs/`. Fresh
setup + the exact two-window login procedure are in
[`.claude/skills/dbmanager/digital-setup.md`](.claude/skills/dbmanager/digital-setup.md).

## Using the Claude Code skill

With Claude Code open in this repo, just ask in plain language — the `dbmanager` skill
routes to the right script and confirms before any destructive restore:

- "list backups"
- "back up the gw suite to r43txho2adm"
- "restore r10 from 03-16"
- "launch policycenter studio for gw43"
- "set up localconfig for a fresh gw43 policycenter checkout" / "back up my localconfig"
- "set up the digital UI repos" / "start the digital UI"

The skill defaults the Postgres user to `vincentwu` and the branch context to `gw43`
unless told otherwise.

## Tests
```bash
bash tests/test_launchstudio.sh
bash tests/test_listbackups.sh
bash tests/test_setup_doctor.sh
bash tests/test_localconfig.sh
```
All use temporary fixture directories and stubbed binaries — they never touch real
databases, checkouts, or backups.

## Configuration

Edit [`launch-config.sh`](launch-config.sh) to point at your IntelliJ / Java installs or
a different `~/dev/bamboo` root. Every value is overridable via environment variables
(which is how the tests run without real installs).
