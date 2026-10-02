# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

Personal tooling for managing local Guidewire suite dev environments: bash scripts to
preflight a machine, back up / restore the suite databases and the per-checkout local
config, start the digital (Jutro) UI apps, and launch Studio — plus a Claude Code skill
(`.claude/skills/dbmanager/`) that orchestrates them and carries the guided setup docs
(`onboarding.md`, `localconfig-setup.md`, `studio-setup.md`, `digital-setup.md`). There is
no build system and no application code — only shell scripts, tests, and the skill.

## Environment facts

- macOS. Default shell is **bash 3.2** — no associative arrays; use `for`/`case`. Keep
  any new scripts bash-3.2 compatible.
- No `shellcheck` or `bats` installed. Tests are plain bash using `tests/assert.sh`.
- Databases: `pcdb` (PolicyCenter), `bcdb` (BillingCenter), `cmdb` (ContactManager).
  ClaimCenter (`ccdb`) is intentionally **out of scope** for backup/restore.
- **H2 or PostgreSQL is a per-center choice**, made in `database-config.xml`: with
  `-Dgw.<xx>.env=local` the suite uses whichever `<database>` block has no `env=`
  attribute. The `env="h2mem"` block is for gunit tests — never present it as a way to run
  the server. `setup-doctor.sh` reads the choice and checks only what it needs.
- Two different Postgres roles, easy to conflate: the dumps are owned by the admin role
  (`vincentwu`), but the suite connects as `pcuser`/`bcuser`/`cmuser`. Dumps carry
  `OWNER TO <role>`, so those roles must exist **before** a restore. Dumps also
  `CREATE EXTENSION` postgis/file_fdw/pg_stat_statements/pgcrypto/unaccent; postgis is a
  separate install.
- Startup is **via Studio** for daily work (a cold `./gwb runServer` is painfully slow).
  Run configs live in each center's gitignored `.idea/`, so every dev builds their own.
  Env flags: `-Dgw.pc.env=local` (:8180), `-Dgw.bc.env=local` (:8580),
  `-Dgw.ab.env=local` (:8280 — ContactManager is **ab**, not cm).
- Digital UI: `agentquotehome` (:3001, HTTPS) and `agentexperience` (:3000, HTTP) under
  `~/dev/bamboo/gw/`. Each pins its Node version in `.nvmrc` with an `engines` range;
  run `npm install` after every branch checkout.
- Backups live in branch-named folders (`r10/`, `r39/`, `r43txho2adm/`, …) as
  `MM-DD_<db>.sql`. `*.sql` is gitignored — never commit backup dumps, and tests must use
  `mktemp -d` fixtures, never the real folders.
- Studio checkouts live under `~/dev/bamboo/<root>/<center>/`. Coding roots: `gw43`,
  `gw35` (and new ones like `gw55`). `gw` and `gw-r1-tx` are snapshot-only — not launch
  targets. Default branch context is `gw43`; default Postgres user is `vincentwu`.
- Studio version combo is uniform: IntelliJ 2024.1.5 Community (default) or Ultimate
  (`--ultimate`), with Java 21. Paths live in `launch-config.sh`.

## Conventions

- Keep helper scripts testable: read config from `launch-config.sh` and make values
  env-overridable; support a dry-run path where it makes sense (see `launchstudio.sh`
  `DRY_RUN=1`).
- Follow TDD for new script behavior: write a `tests/test_*.sh` first, watch it fail,
  then implement. Run with `bash tests/test_*.sh`; success prints `All assertions passed.`
- Match the existing style of the scripts you touch; don't restructure unrelated code.
- The session shell is **zsh** but every script is `#!/bin/bash`. Verify ad-hoc snippets
  with `bash -c '...'` — zsh does not word-split unquoted expansions and needs quoted
  globs, so a check run in zsh can confidently report the wrong answer.
- Don't sample the environment from a non-interactive shell and report it as the user's:
  the `load-nvmrc` hook in their `~/.zshrc` doesn't run there, so `node -v` lies. Check
  the running process or probe a login shell in the target directory.

## Safety

- **This repo is public.** Never commit suite config, credentials, internal URLs, or
  values like `DEPLOYMENT_ID` / the npm registry token. Backups live in gitignored
  `localconfig/backups/`, `digital/backups/` and `*.sql`. Scan a diff before pushing.
- **Guide to a teammate, never guess.** The guided setup docs mark unstorable values
  **ASK A TEAMMATE** (registry token, integration keys, internal endpoints, APD workset
  GUID, `DEPLOYMENT_ID`, local test login). Don't invent a placeholder and move on.
- `setup-doctor.sh` and `localconfig-checkenv.sh` report set/missing only — they must
  never print the value of a credential or env var. Keep it that way.
- **Restore is destructive** — `restore.sh` and `restoregwsuitebydate.sh` drop and
  recreate databases. Always confirm with the user before running a restore, and show
  exactly which DBs will be dropped. The `dbmanager` skill encodes this confirmation gate.
- `drop_database.sh` and `drop_database_exceptlist.sh` are also destructive — same rule.
- `restoregwsuitebydate.sh` continues past a missing `.sql` file (warning only), which can
  leave the suite at mismatched versions. Surface that to the user rather than assuming a
  clean restore.

## Tests

```bash
bash tests/test_launchstudio.sh
bash tests/test_listbackups.sh
bash tests/test_setup_doctor.sh
bash tests/test_localconfig.sh
```

## Design docs

Specs and implementation plans live in `docs/superpowers/`. The original design for the
skill and scripts is `docs/superpowers/specs/2026-06-10-dbmanager-skill-design.md`.

## Git

Remote `origin` → `git@github.com:vwu001/dbmanager.git` (SSH, account `vwu001`). Only
commit or push when asked.
