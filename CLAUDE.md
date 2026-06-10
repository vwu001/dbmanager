# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

Personal tooling for managing local Guidewire suite dev environments: bash scripts to
back up / restore the local PostgreSQL databases and launch Studio, plus a Claude Code
skill (`.claude/skills/dbmanager/`) that orchestrates them. There is no build system and
no application code — only shell scripts, tests, and the skill.

## Environment facts

- macOS. Default shell is **bash 3.2** — no associative arrays; use `for`/`case`. Keep
  any new scripts bash-3.2 compatible.
- No `shellcheck` or `bats` installed. Tests are plain bash using `tests/assert.sh`.
- Databases: `pcdb` (PolicyCenter), `bcdb` (BillingCenter), `cmdb` (ContactManager).
  ClaimCenter (`ccdb`) is intentionally **out of scope** for backup/restore.
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

## Safety

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
```

## Design docs

Specs and implementation plans live in `docs/superpowers/`. The original design for the
skill and scripts is `docs/superpowers/specs/2026-06-10-dbmanager-skill-design.md`.

## Git

Remote `origin` → `git@github.com:vwu001/dbmanager.git` (SSH, account `vwu001`). Only
commit or push when asked.
