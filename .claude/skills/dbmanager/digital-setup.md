# Digital UI — guided setup

How to localize a **fresh** checkout of the two Guidewire Jutro digital apps so they run
against a local suite. Use when there is **no backup** to restore yet. The agent applies
the non-secret edits and pauses for the user to paste their own values; nothing here is
committed to the dbmanager repo.

Repos (under `~/dev/bamboo/gw/`):
- `agentquotehome` — runs on **:3001**
- `agentexperience` — runs on **:3000** (links to agentquotehome on :3001)

Each has local edits to `.env`, `.npmrc`, and `src/config/config.json`.

## 1. .npmrc — registry auth (SECRET)
The `.npmrc` points npm at the Guidewire/internal registry and carries an **auth token**.
**STOP and have the user paste their own token / registry credentials.** Never invent or
commit it.

## 2. .env — local run settings
Set the local run values, e.g.:
- `PORT` — agentquotehome uses `3001`; agentexperience uses the default `3000`.
- `DEPLOY_URL` — point at the local host (`http://localhost:3000` / `https://localhost:3000`).
- Any `*_API_URL` / cloud endpoints — **ask the user** for the environment they mirror
  (these are internal URLs; treat as user-supplied, do not commit).

## 3. src/config/config.json — service endpoints
Point the service URLs at the local suite and the env being mirrored:
- Local suite: PolicyCenter `http://localhost:8180/pc`, ContactManager/ClaimCenter as
  applicable (`:8080/cc`, etc.).
- The cross-app link to agentquotehome (`https://localhost:3001`) for agentexperience.
- Internal cloud / auth endpoints — **ask the user**; these are environment-specific
  internal URLs and are not committed.

## 4. Install dependencies
In each repo: `npm install` (uses `.npmrc` for the registry token).

## 5. Start (correct order)
The suite must be running first (PolicyCenter on :8180). Then:
```
./digital-start.sh
```
This starts **agentquotehome (:3001)** first, waits for it, then **agentexperience
(:3000)**. Logs land in gitignored `digital/logs/`.

## 6. Snapshot the working config
Once it runs, back up so future checkouts are a one-step restore:
```
./digital-backup.sh agentquotehome
./digital-backup.sh agentexperience
```
Backups go to gitignored `digital/backups/` — never committed.
