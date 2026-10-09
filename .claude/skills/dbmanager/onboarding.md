# Fresh machine — ordered setup path

The end-to-end order for getting a new machine running the Guidewire suite + digital UI.
Each stage depends on the one before it. Commands run from the dbmanager repo root unless
a stage says otherwise.

**Nothing in this repo contains credentials or internal values.** Wherever a step says
**ASK A TEAMMATE**, stop and get the value from someone on the team — do not invent it,
do not guess it, and never commit it once you have it.

## What you must get from a teammate

Collect these up front; they block later stages.

| Value | Needed for | Stage |
|---|---|---|
| Repo URLs + which branch each root tracks | cloning the suite and digital repos | 0 |
| `DEPLOYMENT_ID` | the Studio run config (pc, bc) | 4 |
| APD workset GUID for your branch | `config.local.properties` | 3 |
| Internal service / cloud endpoint URLs | `config.local.properties`, `config.json`, `.env` | 3, 5 |
| Integration keys (Verisk, LexisNexis, IG, Okta) | `credentials.xml`, env vars — **live integrations only** | 3 |
| npm registry auth token | `npm install` in the digital apps | 5 |
| Local test login | logging into agentexperience | 6 |

Only the first two are hard blockers. If you do not need live integrations, mock them and
the suite still runs — see "Integrations" in `localconfig-setup.md`.

## Stage 0 — clone

Suite checkouts go to `~/dev/bamboo/<root>/<center>/` (e.g. `gw43/policycenter`), digital
apps to `~/dev/bamboo/gw/<repo>/`. **ASK A TEAMMATE** for the repo URLs and branches.

## Stage 1 — choose your database

You run the server with `-Dgw.<xx>.env=local` (Stage 4). In `local`, the database is
whichever `<database>` element in `modules/configuration/config/database-config.xml` has
**no `env=` attribute**. Exactly one may be uncommented at a time. Pick per center:

| | H2 | PostgreSQL |
|---|---|---|
| Setup | uncomment the H2 block, comment out the PostgreSQL one | leave the PostgreSQL block active |
| Needs a DB server | no | yes, plus roles and extensions |
| Data | file under `./tmp/<center>` | real restorable dumps via `./listbackups.sh` |
| Good for | getting running quickly, light config work | realistic data, anything data-shaped |

Ignore the `env="h2mem"` block — that is **in-memory H2 used by gunit tests**, not a way
to run the server. Leave it alone.

## Stage 2 — preflight

```
./setup-doctor.sh
```

It reads each center's `database-config.xml` and reports which database you chose, then
checks only what that choice needs. On H2 it skips PostgreSQL entirely. On PostgreSQL it
additionally verifies the pieces a restore depends on:

- the server version — 15 or older (see below);
- the databases (`pcdb`, `bcdb`, `cmdb`);
- the **login roles** the suite connects as — `pcuser`, `bcuser`, `cmuser`, plus
  `postgres`. These are *not* the role that owns your dumps. The dumps are full of
  `OWNER TO <role>`, so the roles must exist **before** you restore;
- the **extensions** the dumps create — `postgis`, `file_fdw`, `pg_stat_statements`,
  `pgcrypto`, `unaccent`. PostGIS is a separate install (`brew install postgis`);
  Postgres.app bundles it.

**Use PostgreSQL 15 or older.** The suite runs `SHOW lc_collate` at startup, and 16+
removed that parameter — the server fails with `unrecognized configuration parameter
"lc_collate"`, and no setting re-enables it. Your dumps will restore onto 16/17 without
complaint, so you only find out when the suite starts. In Postgres.app, pick 15 (or 13/14)
when adding the server; on Apple Silicon the v13 binaries need Rosetta
(`softwareupdate --install-rosetta`). Keep `PATH` on the matching `Versions/<N>/bin`.

It also checks IntelliJ/Java, the checkouts, Node against each digital repo's pin, and
required env vars. It never prints the value of any credential or env var. Fix every
`[FAIL]` and re-run until clean.

To load real data (PostgreSQL only): pick a set with `./listbackups.sh`, then restore —
**restore is destructive**, see SKILL.md §3.

## Stage 3 — suite localconfig

Follow `localconfig-setup.md` for each center: the database block you chose in Stage 1,
the plugin registry wiring, the APD workset, credentials, and how to keep these local-only
edits in their own IntelliJ changelist. With a backup from a previous checkout, use
`./localconfig-restore.sh <root> <center>` instead of redoing the edits.

Verify with `./localconfig-checkenv.sh` — all required vars set.

## Stage 4 — start the suite

Follow `studio-setup.md` to build the `Server` run configuration per center. Studio is the
recommended path for daily work; the run configs are gitignored, so you create your own.
This is where `DEPLOYMENT_ID` and the env flag go:

| Center | flag | port |
|---|---|---|
| policycenter | `-Dgw.pc.env=local` | 8180 |
| billingcenter | `-Dgw.bc.env=local` | 8580 |
| contactmanager | `-Dgw.ab.env=local` (**ab**, not cm) | 8280 |

Command line alternative, run from the center directory, not the repo root:

```
cd ~/dev/bamboo/<root>/<center> && ./gwb runServer
```

Verify: PolicyCenter answers on **:8180**.

## Stage 5 — digital UI

Follow `digital-setup.md` for `agentquotehome` and `agentexperience`, or
`./digital-restore.sh <repo>` if you have a backup. Then `nvm use` and `npm install` in
each — re-run `npm install` after every branch checkout or pull.

## Stage 6 — start the digital apps and log in

PolicyCenter must already be up on :8180.

```
./digital-start.sh
```

agentquotehome (:3001) first, then agentexperience (:3000), then the two-window login in
`digital-setup.md` §5. **ASK A TEAMMATE** for the local test account.

## Stage 7 — snapshot everything

```
./localconfig-backup.sh <root> <center>   # per center
./digital-backup.sh <repo>                # per digital repo
./backupgwsuite.sh <owning-role> <branch-folder>   # databases (PostgreSQL only)
```

`<owning-role>` is the role that owns the databases (the one `setup-doctor.sh` connects
as), **not** the `pcuser`/`bcuser`/`cmuser` the suite logs in with. All three write to
gitignored locations, so a future checkout is a one-step restore.
