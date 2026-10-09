---
name: dbmanager
description: Use to set up, back up, restore, and inspect a local Guidewire suite dev environment: the PostgreSQL databases (pcdb, bcdb, cmdb), the per-checkout localconfig and digital UI (Jutro) config, and launching Studio with the correct IntelliJ + Java. Trigger on "set up my environment", "onboard me", "get this running on a new machine", "my suite/digital setup is broken", "check my prerequisites", "back up the gw suite", "list backups", "restore <folder> from <date>", "restore pcdb", "start digital", "launch <center> studio for <root>", or any request to set up, back up, restore, or start the GW suite, the digital apps, or a Studio environment. Operates on this repo's scripts and backup folders.
---

# dbmanager

Orchestrates the setup, backup/restore, and launch scripts in this repo. Run all
commands from the repo root. The Postgres username defaults to `vincentwu` unless the
user says otherwise. Default branch context is `gw43` when the user does not specify.

## 0. Setting up a machine (start here for anything setup-shaped)

If the user is onboarding, on a new machine, or something in their environment is not
working, do NOT jump straight to the per-area docs. Run the preflight first:

```
./setup-doctor.sh
```

It checks PostgreSQL (tools, server, the three DBs), IntelliJ/Java at the
`launch-config.sh` paths, suite checkouts, Node against each digital repo's `.nvmrc` pin,
and required env vars — and prints a remediation hint per failure. It never prints the
value of any credential or env var. Fix the `[FAIL]` lines, re-run until clean, then
follow `onboarding.md` (in this skill directory), which sequences the whole build-out:
clone → choose H2 or PostgreSQL → preflight → localconfig → start the suite → digital →
snapshot.

**Ask which database they want before anything else.** With `-Dgw.<xx>.env=local` the
suite uses whichever `<database>` block in `database-config.xml` has no `env=` attribute:
H2 (no server to install) or PostgreSQL (real restorable dumps, but needs the databases,
the `pcuser`/`bcuser`/`cmuser` login roles, and the PostGIS/fdw/pgcrypto/unaccent
extensions first). The `env="h2mem"` block is for gunit tests — never offer it as a way
to run the server. `setup-doctor.sh` reads the choice per center and checks only what it
needs.

**PostgreSQL must be 15 or older.** The suite runs `SHOW lc_collate` at startup; 16+
dropped that parameter, so the server dies with `unrecognized configuration parameter
"lc_collate"`. There is no setting to bring it back. A restore onto 16/17 succeeds and
looks healthy — the failure only shows at suite startup — so check the server version
(`SHOW server_version`) before restoring, not after. On Apple Silicon, Postgres.app's
v13 binaries need Rosetta (`softwareupdate --install-rosetta`, the user's password).

**Starting the suite is a Studio job.** Follow `studio-setup.md` — the run configurations
are gitignored in every center, so each developer builds their own, and that is where
`DEPLOYMENT_ID` and the env flag live: `-Dgw.pc.env=local`, `-Dgw.bc.env=local`, and
`-Dgw.ab.env=local` for ContactManager (**ab**, not cm). `./gwb runServer` from the center
directory is the alternative.

### The teammate rule (applies everywhere below)

This repo is **public** and deliberately holds **no credentials and no internal values**.
When a step needs something the user does not have — registry auth token, integration
keys, internal endpoint URLs, APD workset GUID, `DEPLOYMENT_ID`, the local test login —
**stop and tell them to ask a teammate**, naming exactly what to ask for. Never invent a
value, never let the user guess, and never commit one once they have it. The guided setup
docs mark these spots **ASK A TEAMMATE**.

Nothing blocks on the optional integration credentials: if the user does not need live
integration servers, they mock those integrations and the suite still runs.

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
commit secret values. Where the user does not have a value, apply the teammate rule in
§0 — the doc marks those spots **ASK A TEAMMATE**.

These edits are permanent local changes to tracked files. `localconfig-setup.md` §5 covers
how to override integration data for local testing (plugin toggle → repoint endpoint →
`.gs` response override, marked `//override testing`), and §8 covers keeping everything in
a dedicated IntelliJ changelist. Integration `.gs` overrides under
`gsrc/bamboo/integration` ARE backed up; the lexisnexis RuntimeProperties and generated
`all.js` are not, and will not come back from a restore.

### Check required env vars
`./localconfig-checkenv.sh` reports which suite env vars are set vs missing. It **never
prints values** — report only set/missing; never echo env values (secret or not) in chat.
Required `[set]` vars (`JAVA_HOME`, `IDEA_HOME`, `GW_PROPERTY_SERVICE_DISABLED=true`,
`GW_TENANT=bamboo`) the skill can help set; `DEPLOYMENT_ID` (`[req]`) the user sets and
changes routinely (swap the env segment, e.g. `qa3`→`dev2`) in their own shell. The
`[opt]`/`[opt-secret]` vars (IG/Okta, etc.) are optional — only needed to hit live
integration servers; otherwise the user mocks those integrations. Never store or commit
any of these values. Names/tags live in `localconfig/required-env.txt`.

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

## 6. Digital UI (Jutro apps)

Two Guidewire Jutro apps under `~/dev/bamboo/gw/` provide the agent UI against a running
local suite: `agentquotehome` (:3001) and `agentexperience` (:3000, links to :3001). Each
has local edits to `.env`, `.npmrc` (registry auth token — secret), and
`src/config/config.json` (internal URLs). **No digital config is ever committed.**

### Setup a fresh checkout (guided)
Follow `digital-setup.md` (in this skill directory): apply the non-secret edits, STOP for
the user to paste their `.npmrc` token and any internal/env URLs, then `nvm use` +
`npm install`. Both repos pin their Node version in `.nvmrc`; `setup-doctor.sh` flags a
mismatch. Re-run `npm install` after every branch checkout or pull. Where the user lacks a
value (registry token, internal endpoints, test login), apply the teammate rule in §0.

### Back up / restore (local only, never committed)
- `./digital-backup.sh <repo>` → captures the modified `.env`/`.npmrc`/`config.json` into
  gitignored `digital/backups/<repo>/`. Selection is git-diff-based (only files differing
  from HEAD); paths in `digital/manifest.txt`. `<repo>` = `agentquotehome` | `agentexperience`.
- `./digital-restore.sh <repo>` → copies the backup back. Errors if none exists.

### Start & login (correct order — PolicyCenter must be running first)
`./digital-start.sh` warns if PolicyCenter (:8180) is down, then starts **agentquotehome
(:3001)** first, waits for it, then **agentexperience (:3000)** (each via `npm run start`).
Apps run in the background; logs in gitignored `digital/logs/`.

The login is a specific two-window dance — walk the user through `digital-setup.md` §5:
open https://localhost:3001/ in a regular window (Advanced → bypass cert; an Okta 400 is
expected — leave it open), then open https://localhost:3000/ in an incognito window and log
in. Never echo `.npmrc` tokens or `.env` secret values.
