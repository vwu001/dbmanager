# Digital UI Management — Design

**Date:** 2026-06-10
**Author:** Vincent Wu
**Status:** Approved for planning

## Problem

Two Guidewire **Jutro** digital apps run the agent-facing UI against a running local suite:

- `~/dev/bamboo/gw/agentquotehome` — runs on **:3001**
- `~/dev/bamboo/gw/agentexperience` — runs on **:3000**, and references `localhost:3001`

Each has local edits to `.env`, `.npmrc` (npm registry auth token — secret), and
`src/config/config.json` (internal `guidewire.net`/okta URLs) needed to run locally. They
must be started in order, and only after the suite (PolicyCenter on `:8180`, etc.) is up.
The dbmanager repo is **public**, so none of this config may be committed.

## Solution Overview

Mirror the localconfig pattern for the digital repos, plus start orchestration:

1. **Local backup/restore** of the modified config files (gitignored, never committed).
2. **Guided setup** instructions (committed, placeholders only) to localize a fresh
   checkout and `npm install`.
3. **Start orchestration** that launches the two apps in the correct order after checking
   the suite is up.

## Scope

In scope:
- Back up / restore `.env`, `.npmrc`, `src/config/config.json` for the two digital repos.
- Guided setup of those files + dependency install for a fresh checkout.
- Start both apps in order (agentquotehome → agentexperience), backgrounded, with logs.

Out of scope:
- Committing any digital config (no copies; secrets/internal URLs stay local).
- Managing the suite itself (covered by the existing skill sections).
- Building/deploying for non-local environments.

## The digital config set

`digital/manifest.txt` lists git pathspecs relative to a repo root:

- `.env`
- `.npmrc`  *(npm registry auth token — secret)*
- `src/config/config.json`  *(internal URLs)*

Backup selection is git-diff-based: only tracked files differing from `HEAD`
(`git -C <repo> diff --name-only HEAD -- <pathspecs>`).

## Repos and startup order

Both live under `${DIGITAL_ROOT:-$HOME/dev/bamboo/gw}`:

| Repo | Port | Start | Depends on |
|---|---|---|---|
| `agentquotehome` | 3001 | `npm start` (`jutro app:start`) | suite (PC :8180) |
| `agentexperience` | 3000 | `npm start` | suite + agentquotehome :3001 |

Order: **agentquotehome first, then agentexperience.** Both require the suite running.

## Components

| Component | Responsibility |
|---|---|
| `digital/manifest.txt` | Git pathspecs for the digital config files |
| `digital-lib.sh` | Shared helpers: resolve repo dir, read manifest, list git-modified files |
| `digital-backup.sh <repo>` | Copy modified config into gitignored `digital/backups/<repo>/` |
| `digital-restore.sh <repo>` | Copy a backup back into the repo |
| `digital-start.sh` | Warn if suite (:8180) down, then start agentquotehome (:3001) → wait → agentexperience (:3000), backgrounded with logs in gitignored `digital/logs/` |
| `.claude/skills/dbmanager/digital-setup.md` | Guided, committed setup instructions (placeholders for secrets/internal URLs) |
| `.claude/skills/dbmanager/SKILL.md` | New "Digital UI" section routing setup / backup / restore / start |
| `.gitignore` | Ignores `digital/backups/` and `digital/logs/` |

Scripts are bash 3.2 compatible.

## Data flow

- **Backup:** `git diff --name-only HEAD -- <pathspecs>` in the repo → copy into
  `digital/backups/<repo>/` → report files captured.
- **Restore:** copy each file under `digital/backups/<repo>/` back into the repo. Refuse if
  no backup exists.
- **Setup (guided):** follow `digital-setup.md`; edit `.env`/`.npmrc`/`config.json` in
  place (placeholders for the npm token and internal URLs), then `npm install`.
- **Start:** check `localhost:8180`; start agentquotehome, wait for `:3001`, then start
  agentexperience; write logs to `digital/logs/<repo>.log` and PIDs to `<repo>.pid`.

## Secrets / public-repo guarantee

- No digital config committed — not `.npmrc` tokens, not internal URLs, not even copies.
- Real config lives only in the repos and gitignored `digital/backups/`.
- `.gitignore` includes `digital/backups/` and `digital/logs/`.

## Error handling

- Missing repo directory → report and stop.
- Backup finds no modified config → report "nothing to back up" and exit 0.
- Restore with no backup present → report and stop.
- Start: suite port down → warn but continue (user may know better); a repo already
  listening on its port → skip starting it; agentquotehome not up within the wait window →
  warn and continue to agentexperience.

## Skill invocation examples

- "back up my digital config" → `digital-backup.sh` for both repos
- "restore agentexperience digital config" → `digital-restore.sh agentexperience`
- "set up the digital UI repos" → guided setup
- "start the digital UI" → `digital-start.sh` (suite must be running)
