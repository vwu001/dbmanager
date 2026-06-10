# localconfig Management — Design

**Date:** 2026-06-10
**Author:** Vincent Wu
**Status:** Approved for planning

## Problem

Each local Guidewire suite checkout (`~/dev/bamboo/<root>/<center>/`) requires a set of
**local modifications to git-tracked files** for the suite to run locally — its
"localconfig." Because these are edits to tracked files (not untracked files), they
collide with git operations, forcing a manual shelve/unshelve dance. A fresh checkout
also won't run until the localconfig is in place. One of the files, `credentials.xml`,
contains secrets that must never be committed.

## Solution Overview

Add a localconfig management capability to the dbmanager repo: committed sanitized
**templates** for setting up fresh checkouts, gitignored **backups** of the user's real
config for quick restore, and `dbmanager` skill workflows to drive backup, restore, and
setup. No git-index manipulation — the user keeps doing manual shelve/unshelve in their
own repo when they choose; the skill provides backup/restore as the alternative.

## Scope

In scope:
- Capture (back up) a suite's localconfig, including the real `credentials.xml`, to a
  gitignored location.
- Restore a previously backed-up localconfig into a suite working tree.
- Set up a fresh checkout from committed, sanitized templates.
- Generate the committed templates from current config, scrubbing secrets.
- Skill routing + secrets guidance for the above.

Out of scope (explicit decisions):
- `git update-index --skip-worktree` or any git-index trickery (user keeps manual
  shelve/unshelve).
- Managing non-config local changes (Gosu `.gs`, generated `all.js`, untracked working
  files) — those are the user's code work, not localconfig.
- ClaimCenter templates initially (templates seed from `gw43` pc/bc/cm; other
  centers/roots can be backed up and promoted later with the same scripts).

## The localconfig set

Defined by a manifest of paths relative to a center root
(`~/dev/bamboo/<root>/<center>/`):

- `modules/configuration/config/config.local.properties`
- `modules/configuration/config/database-config.xml`
- `modules/configuration/credentials.xml`  *(secrets)*
- `modules/configuration/config/plugin/registry/*.gwp`  *(glob)*
- `modules/configuration/etc/bamboo/runtimeproperties/local-dev/RuntimeProperties.lexisnexis.xml`

Manifest lines may be exact paths or globs. A path/glob that matches nothing for a given
center is skipped (centers legitimately differ).

## Two stores

1. **`localconfig/backups/<root>/<center>/…`** — *gitignored.* Full-fidelity copies of
   the user's real localconfig (including real `credentials.xml`), preserving each file's
   relative path. Source for restore; the shelve/unshelve replacement.
2. **`localconfig/templates/<center>/…`** — *committed.* Sanitized per-center templates
   for fresh setup. `credentials.xml` is scrubbed so secret values become `REPLACE_ME`
   placeholders, preserving XML structure and keys. No secrets are ever committed.

## Components

| Component | Responsibility |
|---|---|
| `localconfig/manifest.txt` | Authoritative list of localconfig paths/globs relative to a center root |
| `localconfig-backup.sh <root> <center> [--template]` | Default: copy live config into `backups/<root>/<center>/`. `--template`: scrub `credentials.xml` and write into committed `templates/<center>/` |
| `localconfig-restore.sh <root> <center>` | Copy from `backups/<root>/<center>/` back into the suite working tree |
| `localconfig-setup.sh <root> <center>` | Copy committed `templates/<center>/` into the suite (fresh checkout), then instruct the user to fill `credentials.xml` keys |
| `localconfig-lib.sh` | Shared helpers: resolve center root, read manifest, expand globs, copy preserving relative paths, scrub credentials |
| `.claude/skills/dbmanager/SKILL.md` | New "Local config" section routing backup/restore/setup with secrets guidance |

All scripts are bash 3.2 compatible and resolve the suite path as
`${BAMBOO_ROOT:-$HOME/dev/bamboo}/<root>/<center>` (consistent with `launch-config.sh`).

## Data flow

- **Backup:** read manifest → for each path/glob under the suite, copy into
  `backups/<root>/<center>/` at the same relative path → report files captured.
- **Template generation (`--template`):** same as backup, but target is
  `templates/<center>/`, and `credentials.xml` is scrubbed to placeholders before write.
- **Restore:** for each file present under `backups/<root>/<center>/`, copy back to the
  same relative path under the suite → report files restored. Refuse if no backup exists.
- **Setup:** for each file under `templates/<center>/`, copy into the suite at the same
  relative path → then print a clear reminder to edit `credentials.xml` with real keys.

## Secrets handling

- Real `credentials.xml` exists only in (a) the suite working tree and (b) gitignored
  `localconfig/backups/`.
- Only the scrubbed placeholder `credentials.xml` is committed (under `templates/`).
- `.gitignore` gains `localconfig/backups/`.
- Scrub never writes real secret values to a committed path; it reads the live file,
  replaces secret values with `REPLACE_ME`, and writes the result to `templates/`.

## Error handling

- Missing suite directory (`~/dev/bamboo/<root>/<center>`) → report and stop.
- Restore with no backup present → report and stop (don't silently no-op into a broken
  setup).
- Setup overwriting existing localconfig → warn before overwriting.
- Backup overwriting an existing backup for the same root/center → warn before
  overwriting.
- A manifest glob matching nothing → skip silently (expected per-center variance).

## Initial seeding

Generate committed templates from the current `gw43` checkouts for `policycenter`,
`billingcenter`, and `contactmanager` using `localconfig-backup.sh <root> <center>
--template`, with `credentials.xml` scrubbed to placeholders.

## Skill invocation examples

- "back up my localconfig for gw43 pc"
- "restore localconfig for gw43 policycenter"
- "set up localconfig for a fresh gw43 billingcenter checkout"
- "regenerate the localconfig template for contactmanager"
