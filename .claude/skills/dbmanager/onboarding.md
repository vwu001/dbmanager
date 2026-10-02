# Fresh machine — ordered setup path

The end-to-end order for getting a new machine running the Guidewire suite + digital UI.
Each stage depends on the one before it; do not skip ahead. Run every command from the
dbmanager repo root.

**Nothing in this repo contains credentials or internal values.** Wherever a step says
**ASK A TEAMMATE**, stop and get the value from someone on the team — do not invent it,
do not guess it, and never commit it once you have it.

## What you must get from a teammate

Collect these up front; they block later stages. None of them can live in this repo
(it is public), and the skill cannot derive them:

| Value | Needed for | Stage |
|---|---|---|
| Repo URLs + which branch each root tracks | cloning the suite and digital repos | 0 |
| npm registry auth token (`.npmrc`) | `npm install` in the digital apps | 4 |
| Internal service / cloud endpoint URLs | `config.json`, `.env`, `config.local.properties` | 3, 4 |
| APD workset GUID for your branch | `config.local.properties` | 3 |
| `DEPLOYMENT_ID` base string | suite build/run | 3 |
| Integration keys (Verisk, LexisNexis, IG, Okta) | `credentials.xml`, env vars — **only for live integrations** | 3 |
| Local test login for the digital apps | logging into agentexperience | 5 |

If you do not need live integrations, you can skip every integration key and mock those
integrations instead — the suite will still run.

## Stage 0 — clone

Suite checkouts go to `~/dev/bamboo/<root>/<center>/` (e.g. `gw43/policycenter`), digital
apps to `~/dev/bamboo/gw/<repo>/`. **ASK A TEAMMATE** for the repo URLs and the branch each
root should track.

## Stage 1 — preflight

```
./setup-doctor.sh
```

Checks PostgreSQL tools + server + the three databases, IntelliJ/Java at the
`launch-config.sh` paths, suite checkouts, Node against each digital repo's `.nvmrc` pin,
and required env vars. Fix everything it reports as `[FAIL]`, then re-run until clean.
It never prints the value of any credential or env var.

## Stage 2 — databases

The suite needs `pcdb`, `bcdb`, `cmdb` to exist. `setup-doctor.sh` tells you which are
missing; create them with `createdb -U <role> <db>`. To load real data, pick a set with
`./listbackups.sh` and restore it — **restore is destructive**, see SKILL.md §3.

## Stage 3 — suite localconfig

Follow `localconfig-setup.md` for each center. If you already have a backup from a
previous checkout, skip the guided edits and run
`./localconfig-restore.sh <root> <center>` instead.

Verify: `./localconfig-checkenv.sh` reports all required vars set, and
`./gwb runServer -Denv=local` brings PolicyCenter up on **:8180**.

Snapshot once it works: `./localconfig-backup.sh <root> <center>`.

## Stage 4 — digital UI config

Follow `digital-setup.md` for each of `agentquotehome` and `agentexperience`. With a
backup in hand, `./digital-restore.sh <repo>` replaces the guided edits.

Then, in each repo: `nvm use` (honours `.nvmrc`) and `npm install`. Re-run `npm install`
after **every** branch checkout or pull — dependencies move.

Snapshot once it works: `./digital-backup.sh <repo>`.

## Stage 5 — start and log in

PolicyCenter must already be up on :8180.

```
./digital-start.sh
```

Starts agentquotehome (:3001) first, waits, then agentexperience (:3000). Then do the
two-window login in `digital-setup.md` §5. **ASK A TEAMMATE** for the local test account.

## Stage 6 — snapshot everything

```
./localconfig-backup.sh <root> <center>   # per center
./digital-backup.sh <repo>                # per digital repo
./backupgwsuite.sh <role> <branch-folder> # databases
```

All three write to gitignored locations. From here, a fresh checkout is a one-step
restore rather than a repeat of this document.
