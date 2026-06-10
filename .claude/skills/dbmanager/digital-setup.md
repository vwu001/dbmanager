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

## 5. Start & login (exact working procedure)

**Prerequisite: PolicyCenter must already be started first** (suite running on :8180).

1. Start the apps in order — **agentquotehome first, then agentexperience** — each with
   `npm run start` (the `start` script = `jutro app:start`; there is no `dev` script).
   Helper:
   ```
   ./digital-start.sh
   ```
   (starts agentquotehome :3001, waits, then agentexperience :3000; logs in `digital/logs/`).

2. In a **regular browser window**, open **https://localhost:3001/**. Click **Advanced** →
   proceed past the "your connection is not private" warning. It loads and then shows a
   **400 error from Okta** — that is expected. **Leave this window open and do nothing with
   it.**

3. Open a separate **incognito window** and go to **https://localhost:3000/**
   (agentexperience). Log in with the local test account:
   - username: `<LOCAL_TEST_USERNAME>`
   - password: `<LOCAL_TEST_PASSWORD>`

   (Local-only test login — works only against a local environment, not a real secret.)
   The app then loads and works.

## 6. Snapshot the working config
Once it runs, back up so future checkouts are a one-step restore:
```
./digital-backup.sh agentquotehome
./digital-backup.sh agentexperience
```
Backups go to gitignored `digital/backups/` — never committed.
