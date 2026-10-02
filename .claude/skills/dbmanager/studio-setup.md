# Studio run configurations — guided setup

How to create the IntelliJ run configurations that start a center locally.

**Start the suite from Studio for day-to-day development.** `./gwb runServer` works and is
a fine fallback, but a cold command-line start is slow enough to be painful to iterate on;
Studio reuses the incremental build and gives you the debugger.

**These configurations are not in the repo.** `.idea/` is gitignored in every center, so
each developer creates their own. Nothing below is copied from one machine to another.

## What you need from a teammate first

`DEPLOYMENT_ID` — a long opaque internal identifier: a colon-separated string ending in a
`/deployment/<name>` path, with an environment segment partway through. It is not
derivable and its format is deliberately not spelled out in this public repo. **ASK A TEAMMATE** for a current value, then swap the
environment segment to whichever environment you are mirroring. PolicyCenter and
BillingCenter will not start without it.

## Per-center settings

Create an **Application** run configuration named `Server` in each center project.

Shared by all three:

| Field | Value |
|---|---|
| Main class | `com.guidewire.commons.jetty.GWServerJettyServerMain` |
| Module (`-cp`) | `configuration` |
| Working directory | the center root, e.g. `~/dev/bamboo/gw43/policycenter` |
| JRE | Corretto 21 |
| Before launch | **Make (Including OSGi Bundles)** — required; a plain Make will not do |

Shared VM options:

```
-server -ea -Xdebug -Djava.awt.headless=true -Dgw.server.mode=dev -Dgwdebug=true
-Dgw.webapp.dir=idea/webapp -Dgw.classpath.jar=true -Dgw.plugins.gclasses.dir=idea-gclasses
-DgosuInit.supportDiscretePackages=true -Djava.locale.providers=COMPAT
--add-opens=java.base/sun.reflect.annotation=ALL-UNNAMED
```

Then add the per-center part:

| Center | env flag | HTTP port | Heap | Debug port | Environment variables |
|---|---|---|---|---|---|
| policycenter | `-Dgw.pc.env=local` | `-Dgw.port=8180` | `-Xmx8g` | 8123 | `GW_PROPERTY_SERVICE_DISABLED=true`, `GW_TENANT=bamboo`, `DEPLOYMENT_ID=<ask a teammate>` |
| billingcenter | `-Dgw.bc.env=local` | `-Dgw.port=8580` | `-Xmx4g` | 8523 | `DEPLOYMENT_ID=<ask a teammate>` |
| contactmanager | `-Dgw.ab.env=local` | `-Dgw.port=8280` | `-Xmx4g` | 8223 | none |

**ContactManager's flag is `gw.ab.env`, not `gw.cm.env`** — it is the AddressBook app.
Getting this wrong starts the server against the wrong configuration with no obvious error.

PolicyCenter also needs two Jetty form limits, or large submissions fail:

```
-Dorg.eclipse.jetty.server.Request.maxFormContentSize=4000000
-Dorg.eclipse.jetty.server.Request.maxFormKeys=10000
```

and one extra **Before launch** step ahead of Make — a Gradle task,
`generateCloudRatingCustomRateFunctionZip`.

`-Dgw.<xx>.env=local` is what selects the `local` environment, and `local` is what picks
up the config you edited in `localconfig-setup.md`. It is **not** interchangeable with
`env=h2mem`, which exists for gunit tests only — see `onboarding.md`.

## DropDB

A second Application configuration, useful for resetting between data loads:
main class `com.guidewire.testharness.db.DBResetTool`, same module and working directory,
VM options as above minus the port and heap flags. **It destroys the center's data** —
confirm which database it points at before running it.

## Starting up

PolicyCenter on :8180 is the one the digital UI needs. Start ContactManager first if you
are exercising contact lookups, then PolicyCenter, then BillingCenter if you need billing.
