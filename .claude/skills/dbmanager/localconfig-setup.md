# localconfig — guided setup

How to localize a **fresh** suite checkout (`~/dev/bamboo/<root>/<center>/`) so it runs
with `-Denv=local`. Use this when there is **no backup** to restore yet. The agent applies
the non-secret edits and pauses for the user to paste their own keys; nothing here is
committed to the dbmanager repo.

Centers: `policycenter` (pc / `pcdb`), `billingcenter` (bc / `bcdb`),
`contactmanager` (cm / `cmdb`). Paths below are under
`modules/configuration/` in the center checkout.

## 1. database-config.xml — point at local PostgreSQL
Comment out the H2 demo block, and enable a local PostgreSQL `<database>` block:

```xml
<database name="<Center>Database" autoupgrade="full" dbtype="postgresql">
  <dbcp-connection-pool
    jdbc-url="jdbc:postgresql://localhost:5432/<DB>?user=<DBUSER>&amp;password=<YOUR_DB_PASSWORD>">
  </dbcp-connection-pool>
</database>
```

- `<Center>Database` / `<DB>` / `<DBUSER>`: PolicyCenter→`pcdb`/`pcuser`,
  BillingCenter→`bcdb`/`bcuser`, ContactManager→`cmdb`/`cmuser`.
- **Ask the user** for `<YOUR_DB_PASSWORD>` (their local postgres password).

## 2. plugin/registry/*.gwp — enable the `local` env
For the integration plugins that ship enabled only for `cloud-dev`, add `local` to the
env list so they activate locally:

- Change `env="cloud-dev"` → `env="cloud-dev,local"` on the relevant `<plugin-gosu>` lines.
- Give the StandAlone variants `env="h2mem"`.
- In `RuntimePropertiesPlugin.gwp`, ensure the active entry is `env="local"`.

Which `.gwp` files are affected differs per center (e.g. pc: `ContactSystemPlugin`,
`IAddressBookAdapter`, `IBillingSummaryPlugin`, `IBillingSystemPlugin`,
`RuntimePropertiesPlugin`). These are non-secret wiring edits — apply them directly.

## 3. config.local.properties — APD workset + product URLs
- Uncomment the `apd.service.devWorkset=<GUID>` line for the branch being worked on, and
  comment out the others. **Ask the user** which workset GUID applies if unclear.
- Confirm the local suite product URLs are present (the `localhost:8x80/..` entries).

## 4. credentials.xml — user's own keys (SECRETS)
Leave standard dev defaults (`ClientAppSuite`/`gw`) as-is. For real integrations,
**STOP and have the user paste their own values** — do not invent or commit them. Common
entries that need real keys: `veriskvproperties.acc.password`,
`lexisnexisproperties.*`, `gw.asmanage.ig.oauth.client*`. Mark any unfilled ones as
`REPLACE_ME` so the user can find them.

## 5. RuntimeProperties.lexisnexis.xml — set manually
This file is intentionally not managed by this skill. Set the lexisnexis RuntimeProperties
value to **delegate** (it defaults to `none`) for the user's environment.

## 6. Environment variables
The suite needs several env vars set at build/run time. Run the checker and report what's
set vs missing — it shows non-secret values and masks secrets:

```
./localconfig-checkenv.sh
```

Names + tags live in `localconfig/required-env.txt`:
- **`[set]` — help the user set these** (non-sensitive, known): `JAVA_HOME` / `IDEA_HOME`
  (same as `launch-config.sh`), `GW_PROPERTY_SERVICE_DISABLED=true`, `GW_TENANT=bamboo`.
- **`DEPLOYMENT_ID` (`[user-show]`)** — the one devs change routinely. Keep the structure
  but swap the environment segment (e.g. the `qa3` in `...:dev:qa3:/deployment/...`) to the
  env being mirrored (`dev2`, etc.). The checker prints the current value so the user can
  confirm/adjust it.
- **`[user]` — the user obtains and exports these themselves** (secrets / account-specific):
  `JBR_DIR`, `IG_ARTIFACT_REPO_USERNAME`/`_PASSWORD`, `IG_EDGE_NODE_USERNAME`/`_PASSWORD`,
  `OKTA_CLIENT_ID`/`_SECRET`/`_AUTH_SERVER_URL`/`_SCOPE`. Never store or commit these; just
  tell the user which are missing.

Also run the server in the local env via `-Denv=local` (gwb arg / Studio run config),
which is a JVM property, not an exported env var.

## 7. Run and snapshot
- Start the server in the `local` env:
  - cmdline: `./gwb runServer -Denv=local`
  - Studio: add `-Dgw.<xx>.env=local` to the run configuration.
- Once it runs, snapshot the working setup so future checkouts are a one-step restore:
  `./localconfig-backup.sh <root> <center>` (writes to gitignored `localconfig/backups/`).
