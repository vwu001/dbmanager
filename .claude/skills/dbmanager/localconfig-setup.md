# localconfig — guided setup

How to localize a **fresh** suite checkout (`~/dev/bamboo/<root>/<center>/`) so it runs
with `-Denv=local`. Use this when there is **no backup** to restore yet. The agent applies
the non-secret edits and pauses for the user to paste their own keys; nothing here is
committed to the dbmanager repo.

**When the user does not have a value, tell them to ask a teammate.** Every item marked
ASK A TEAMMATE below is deliberately absent from this repo (it is public) and cannot be
derived — do not invent a placeholder and move on, and do not let the user guess. Stop,
name exactly what they need to ask for, and wait.

Centers: `policycenter` (pc / `pcdb`), `billingcenter` (bc / `bcdb`),
`contactmanager` (cm / `cmdb`). Paths below are under
`modules/configuration/` in the center checkout.

## 1. database-config.xml — pick H2 or PostgreSQL

Running with `-Dgw.<xx>.env=local`, the suite uses whichever `<database>` element has
**no `env=` attribute**. Exactly one may be uncommented. Ask the user which they want.

**Leave the `env="h2mem"` block alone** — that is in-memory H2 for gunit tests, not a way
to run the server. Same for `env="cloud-dev"`, which is for deployed environments.

### Option A — H2 (no database server)
Uncomment the H2 block and comment out the PostgreSQL one:

```xml
<database autoupgrade="full" dbtype="h2" name="<Center>Database">
  <dbcp-connection-pool jdbc-url="jdbc:h2:file:./tmp/<xx>;AUTO_SERVER=true;CACHE_SIZE=64000;"/>
</database>
```

Nothing else to install. Data lives in a file under the center's `tmp/` and survives
restarts, but it cannot be loaded from the suite dumps in this repo.

### Option B — PostgreSQL
Leave the PostgreSQL block uncommented and comment out H2:

```xml
<database name="<Center>Database" autoupgrade="full" dbtype="postgresql">
  <dbcp-connection-pool
    jdbc-url="jdbc:postgresql://localhost:5432/<DB>?user=<DBUSER>&amp;password=<YOUR_DB_PASSWORD>">
  </dbcp-connection-pool>
</database>
```

- PolicyCenter→`pcdb`/`pcuser`, BillingCenter→`bcdb`/`bcuser`, ContactManager→`cmdb`/`cmuser`.
- **Ask the user** for `<YOUR_DB_PASSWORD>` (their own local postgres password).
- The `<DBUSER>` roles must exist in PostgreSQL before any restore — `./setup-doctor.sh`
  checks this, along with the extensions the dumps need.

## 2. plugin/registry/*.gwp — enable the `local` env
For the integration plugins that ship enabled only for `cloud-dev`, add `local` to the
env list so they activate locally:

- Change `env="cloud-dev"` → `env="cloud-dev,local"` on the relevant `<plugin-gosu>` lines.
- Give the StandAlone variants `env="h2mem"`.
- In `RuntimePropertiesPlugin.gwp`, ensure the active entry is `env="local"`.

Which `.gwp` files are affected differs per center. PolicyCenter:
`ContactSystemPlugin`, `IAddressBookAdapter`, `IBillingSummaryPlugin`,
`IBillingSystemPlugin`, `RuntimePropertiesPlugin`. **The BillingCenter and ContactManager
lists are not recorded here** — grep the center's `plugin/registry` for `env="cloud-dev"`
to find the candidates, and if it is not obvious which ones matter, **ASK A TEAMMATE**
rather than enabling plugins at random.

These are non-secret wiring edits — apply them directly.

## 3. config.local.properties — APD workset + product URLs
- Uncomment the `apd.service.devWorkset=<GUID>` line for the branch being worked on, and
  comment out the others. **Ask the user** which workset GUID applies. A new joiner has no
  way to know this — if they are unsure, **ASK A TEAMMATE** which workset belongs to the
  branch they are on. Picking the wrong one silently loads the wrong product model.
- Confirm the local suite product URLs are present (the `localhost:8x80/..` entries).

## 4. credentials.xml — user's own keys (SECRETS)
Leave standard dev defaults (`ClientAppSuite`/`gw`) as-is. For real integrations,
**STOP and have the user paste their own values** — do not invent or commit them. Common
entries that need real keys: `veriskvproperties.acc.password`,
`lexisnexisproperties.*`, `gw.asmanage.ig.oauth.client*`. Mark any unfilled ones as
`REPLACE_ME` so the user can find them.

**ASK A TEAMMATE** for any of these the user does not already hold — they are vendor and
internal integration credentials, not self-service. They are only needed to hit **live**
integrations: if the user does not need live servers, leave them `REPLACE_ME`, mock those
integrations, and the suite will still start.

## 5. Overriding integration data for local testing

A local run often needs a vendor call to return something specific — a particular score, a
failure path, or simply *anything* when you have no credentials for that vendor. Reach for
these in order; the first two are config, the third is real code.

**a. Turn the plugin off, or point it at the mock** — `config/plugin/registry/*.gwp` (§2).
Cleanest option: no code touched. Use it when you want the integration out of the way.

**b. Repoint the endpoint** — the service URLs in `config.local.properties` (§3). Use it
when you want a real call, but against a different environment.

**c. Override the response in the integration service** — the `.gs` under
`modules/configuration/gsrc/bamboo/integration/<vendor>/`. Use it when you need one
specific *value* back. Two shapes:

```gosu
// (1) let the real call happen, then force one field before returning
var delegator = new SomeServiceDelegate(_SERVICE_NAME, request)
delegator.invokeService()
//override testing
//delegator.ResponseDTO.VendorResponse.<path>.<field> = <fixed value>
return delegator.ResponseDTO

// (2) skip the vendor entirely — for when you have no credentials at all
//override testing
//return buildCannedResponse()
```

Conventions that keep this from biting you:

- **Mark every override with the same comment** (`//override testing` is the one in use).
  Before any commit or handover, `grep -rn "override testing" modules/configuration/gsrc`
  finds all of them. An unmarked override is indistinguishable from real work.
- **Comment the original line out rather than deleting it**, so reverting is a comment
  flip and the intended call path stays readable.
- **Never commit these.** Keep them in the localconfig changelist (§8).

These `.gs` overrides **are** captured by `./localconfig-backup.sh` and come back with
`./localconfig-restore.sh` — but only under
`modules/configuration/gsrc/bamboo/integration`. Feature work in `.gs` files elsewhere is
deliberately not captured, so do not park real work in the integration tree.

If what you actually need is a working vendor call rather than a fake one, that is keys,
not code: **ASK A TEAMMATE** and fill in `credentials.xml` (§4).

## 6. RuntimeProperties.lexisnexis.xml — set manually
This file is intentionally not managed by this skill. Set the lexisnexis RuntimeProperties
value to **delegate** (it defaults to `none`) for the user's environment.

## 7. Environment variables
The suite needs some env vars at build/run time. Run the checker and report what's set vs
missing — it **only reports set/missing and never prints values** (they stay masked):

```
./localconfig-checkenv.sh
```

Names + tags live in `localconfig/required-env.txt`:
- **Required, `[set]` — help the user set these** (non-sensitive, known): `JAVA_HOME` /
  `IDEA_HOME` (same as `launch-config.sh`), `GW_PROPERTY_SERVICE_DISABLED=true`,
  `GW_TENANT=bamboo`.
- **Required, `[req]` — the user sets it:** `DEPLOYMENT_ID`. The routinely-changed one —
  keep the structure but swap the environment segment (e.g. the `qa3` in
  `...:dev:qa3:/deployment/...`) to the env being mirrored (`dev2`, etc.). The user
  checks/changes the actual value in their own shell; the skill never echoes it.
  A new joiner has no base string to edit — **ASK A TEAMMATE** for the full
  `DEPLOYMENT_ID` format and a current value to start from.
- **Optional, `[opt]` / `[opt-secret]` — only to hit LIVE integration servers:** `JBR_DIR`,
  `IG_ARTIFACT_REPO_USERNAME`/`_PASSWORD`, `IG_EDGE_NODE_USERNAME`/`_PASSWORD`,
  `OKTA_CLIENT_ID`/`_SECRET`/`_AUTH_SERVER_URL`/`_SCOPE`. Not required to get the suite
  running — if the user doesn't need live integrations, they set those integrations to
  **mock** instead. When needed, **ASK A TEAMMATE** for them; never store or commit the values, and never
  echo them in chat.

Also run the server in the local env via `-Denv=local` (gwb arg / Studio run config),
which is a JVM property, not an exported env var.

## 8. Keep these edits in their own changelist

All of the above are permanent local edits to tracked files — they must never be
committed. Put them in a dedicated IntelliJ changelist (e.g. named `localconfig`) so they
stay visibly separate from real work and are easy to shelve before a branch switch.

What typically lives there, and what each is for:

| File | Purpose | In `localconfig-backup.sh`? |
|---|---|---|
| `database-config.xml` | H2 vs PostgreSQL (§1) | yes |
| `config.local.properties` | APD workset + local product URLs (§3) | yes |
| `credentials.xml` | integration keys — **ask a teammate** (§4) | yes |
| `*.gwp` under `config/plugin/registry` | which integration plugins are live locally (§2) | yes |
| `RuntimeProperties.lexisnexis.xml` | lexisnexis delegate vs none (§5) | **no — set manually** |
| Integration service `.gs` overrides under `gsrc/bamboo/integration` | forcing a fixed vendor response for local testing (§5) | yes |
| Generated `all.js` | build output that shows as modified | **no** |

The last two are deliberately outside the backup manifest, so note them: after a fresh
checkout they do not come back with `./localconfig-restore.sh` and must be redone by hand.

**Changing an integration locally** is one of three moves — see §5 for the full pattern.
All three now survive a backup/restore cycle.

**Changing credentials** is always `credentials.xml`, and the values always come from a
person — **ASK A TEAMMATE** for the keys. Never invent them, never commit them.

## 9. Run and snapshot
- Start the server in the `local` env — see `studio-setup.md`. Studio is the recommended
  path for daily work; `./gwb runServer` from the center directory is the alternative.
  The env flag is `-Dgw.pc.env=local`, `-Dgw.bc.env=local`, `-Dgw.ab.env=local`
  (ContactManager is **ab**, not cm).
- Once it runs, snapshot the working setup so future checkouts are a one-step restore:
  `./localconfig-backup.sh <root> <center>` (writes to gitignored `localconfig/backups/`).
