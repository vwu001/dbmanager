# localconfig Management — Design

**Date:** 2026-06-10
**Author:** Vincent Wu
**Status:** Approved for planning

## Problem

Each local Guidewire suite checkout (`~/dev/bamboo/<root>/<center>/`) requires a set of
**local modifications to git-tracked files** for the suite to run locally (with
`-Denv=local`) — its "localconfig." Because these are edits to tracked files, they collide
with git operations, forcing a manual shelve/unshelve dance. A fresh checkout won't run
until the localconfig is in place. One file, `credentials.xml`, contains secrets; other
files contain internal URLs. The dbmanager repo is **public**, so none of this content may
be committed.

## Solution Overview

Two parts, neither of which commits any suite config:

1. **Guided setup** — committed *instructions* (`localconfig-setup.md`) that the skill
   follows to edit the base files of a fresh checkout in place. The agent applies the
   non-secret edits and pauses for the user to paste their own keys. No copies of config
   are stored in the repo.
2. **Local backup/restore** — scripts that snapshot the user's real localconfig to a
   **gitignored** `localconfig/backups/` directory and restore it. This is the
   shelve/unshelve replacement and the fast path for future fresh checkouts (after the
   first guided setup + backup).

No `skip-worktree` / git-index manipulation — the user keeps manual shelve/unshelve in
their own repo when they choose.

## Scope

In scope:
- Guided, documented setup of a fresh checkout's localconfig (edit base files in place).
- Back up a suite's localconfig (incl. real `credentials.xml`) to a gitignored location.
- Restore a backed-up localconfig into a suite working tree.

Out of scope (explicit decisions):
- Committing any suite config to the repo (no templates, no scrubbed copies).
- `git update-index --skip-worktree` or any git-index trickery.
- Managing non-config local changes (Gosu `.gs`, generated `all.js`, untracked files).
- `RuntimeProperties.lexisnexis.xml` — intentionally not managed; the setup doc reminds
  the user to set its value to delegate (default `none`) manually.

## The localconfig set

The manifest (`localconfig/manifest.txt`) lists **git pathspecs** relative to a center
root:

- `modules/configuration/config/config.local.properties`
- `modules/configuration/config/database-config.xml`
- `modules/configuration/credentials.xml`  *(secrets — only ever in suite + gitignored backups)*
- `modules/configuration/config/plugin/registry`  *(directory — many `.gwp`, only some modified)*

**Backup selection is git-diff-based, not glob-based:** only tracked files under these
pathspecs that differ from `HEAD` are captured —
`git -C <suite> diff --name-only HEAD -- <pathspecs>`. Essential because the registry
directory holds ~180 `.gwp` files but only the handful actually modified are localconfig;
it also excludes code work (`.gs`, generated `all.js`) outside these pathspecs.

## Components

| Component | Responsibility |
|---|---|
| `.claude/skills/dbmanager/localconfig-setup.md` | Guided, committed instructions to localize a fresh checkout (non-secret edits concrete; secrets/URLs as user-supplied placeholders) |
| `localconfig/manifest.txt` | Authoritative list of localconfig git pathspecs |
| `localconfig-lib.sh` | Shared helpers: resolve suite path, read manifest, list git-modified localconfig files |
| `localconfig-backup.sh <root> <center>` | Copy modified localconfig into gitignored `localconfig/backups/<root>/<center>/` |
| `localconfig-restore.sh <root> <center>` | Copy a backup back into the suite working tree |
| `.claude/skills/dbmanager/SKILL.md` | "Local config" section routing setup / backup / restore |
| `.gitignore` | Ignores `localconfig/backups/` |

Scripts are bash 3.2 compatible and resolve the suite as
`${BAMBOO_ROOT:-$HOME/dev/bamboo}/<root>/<center>` (consistent with `launch-config.sh`).

## Data flow

- **Setup (guided):** agent follows `localconfig-setup.md`, editing the suite's base files
  in place; pauses for the user to paste keys (DB password, credentials, integration URLs).
  Nothing is read from or written to the repo's tracked files.
- **Backup:** `git diff --name-only HEAD -- <pathspecs>` in the suite → copy each file into
  `backups/<root>/<center>/` at the same relative path → report files captured.
- **Restore:** for each file under `backups/<root>/<center>/`, copy back to the same
  relative path in the suite. Refuse if no backup exists.

## Secrets / public-repo guarantee

- No suite config is committed — not credentials, not internal URLs, not even sanitized
  copies. The repo only carries scripts, the manifest, the gitignore rule, and the guided
  instructions (which use placeholders for anything sensitive).
- Real `credentials.xml` exists only in the suite and in gitignored `localconfig/backups/`.
- `.gitignore` includes `localconfig/backups/`.

## Error handling

- Missing suite directory → report and stop.
- Backup finds no modified localconfig → report "nothing to back up" and exit 0.
- Restore with no backup present → report and stop (don't half-restore into a broken setup).
- Backup overwriting an existing backup for the same root/center → warn before overwriting.

## Skill invocation examples

- "set up localconfig for a fresh gw43 policycenter checkout" → guided setup
- "back up my localconfig for gw43 pc" → `localconfig-backup.sh`
- "restore localconfig for gw43 billingcenter" → `localconfig-restore.sh`
