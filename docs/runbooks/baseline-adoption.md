# Conceptual runbook: production baseline adoption

## Status

Conceptual only. This is not authorization to access production and intentionally contains no executable command, credential, hostname, or database name.

## Objective

Adopt the already-existing production schema into Flyway history without recreating or changing the 107 exported application tables.

## Required approvals

- Fernando approves the adoption version and window.
- Database, API, Discord, and operations reviewers approve the fingerprint.
- Backup owner confirms a successful restore test.
- Operations confirms the legacy Discord runner is not invoked.

## Preconditions

- Flyway implementation phase is separately approved.
- The Flyway version and MariaDB driver are pinned and validated against MariaDB 10.6.
- The candidate sanitized canonical baseline exists at `flyway/sql/baseline/B20261020_001__adopt_production_schema.sql` with adoption version `20261020.001`. This is a proposed version for eventual approval, NOT authorization to baseline production.
- The structural fingerprint matches the current production database.
- No unresolved drift exists.
- Runtime/manual DDL is quiesced for the adoption window.
- The production target identity is independently verified.
- Backup and recovery evidence is current.

## Evidence package

- source dump checksum;
- normalized schema fingerprint;
- MariaDB version, charset, and collation metadata;
- expected table count;
- sanitized baseline checksum;
- ownership-manifest version;
- read-only capture of legacy `schema_migrations` rows;
- reviewer and operator approvals;
- expected Flyway baseline version and description.

## Preparing a future read-only fingerprint review (not a production procedure)

This section prepares **evidence collection only**. It does not grant permission
to connect to the production VM or MariaDB, and the repository intentionally has
no live-database capture command, credential, host or production workflow.

### Reference capture from a disposable baseline

An authorized developer can generate the **expected** metadata using the
existing pinned disposable harness. Choose a fresh, private path *outside*
the repository and ensure the file does not already exist:

```bash
python validation/scripts/physical_schema_fingerprint.py capture-disposable /private/expected-physical-schema.json
```

This mode is hard-coded to the isolated Compose test database. It checks the
local Docker context, starts the 107-table baseline in a disposable database,
excludes `flyway_schema_history` from structural comparison, and tears down
its containers and volumes. It is **not** a way to capture production.

### Live observed capture — separately authorized and privately executed

Only after a **separate explicit read-only authorization**, the DBA/operator
must independently verify the intended database target and use a restricted
account with sufficient *metadata visibility* for all 107 application tables.
Permissions and completeness must be established before relying on the result;
an incomplete account can produce a misleading partial inventory. Do not
use API/Coddy credentials, expose database connectivity to GitHub runners,
or connect this repository's disposable Compose harness to the live database.

The exact five SELECT-only queries and one environment query are maintained
in `validation/scripts/physical_schema_fingerprint.py` under `QUERIES` and
`ENVIRONMENT_QUERY`.

For HeidiSQL operators, an optional [single-query metadata export and offline
CSV importer](heidisql-readonly-fingerprint-export.md) produces the exact same
five-section JSON contract without entering connection credentials into the
repository. This shortcut does **not** waive read-only account restrictions,
completeness checks or the separate backup-restore gate. All five read `information_schema` with the selected
`DATABASE()` scope. **Do not execute the Python capture-disposable adapter
against production or modify it to accept live connection details.**

The independently authorized operator may export the returned JSON objects
from each query, in their existing array of records, to a private JSON file
using the following contract:

```json
{
  "format": "brafurries-mariadb-physical-schema-v1",
  "sections": {
    "tables": [],
    "columns": [],
    "indexes": [],
    "foreign_keys": [],
    "checks": []
  },
  "environment": {}
}
```

The arrays shown are **placeholders**, not valid evidence. Each section must
contain **all records** returned by its corresponding query (an empty
`foreign_keys` or `checks` array is structurally legal, but unexpected for
this schema). The `environment` object is the single JSON result of the
environment query. These results contain metadata (possibly sensitive object
names and check expressions), **not** application rows; nevertheless keep
the observed snapshot, command history, review package and database identity
outside Git, PRs, chats, public CI artifacts and shared logs.

### Offline comparison and acceptance criteria

Compare the private expected and observed files on a trusted workstation,
without any database connection:

```bash
python validation/scripts/physical_schema_fingerprint.py compare /private/expected-physical-schema.json /private/observed-physical-schema.json
```

Exit code **0** means the represented normalized metadata matches; **1**
means physical drift, and **2** means invalid/incomplete input. The comparator
prints hashes and object/field names of up to 60 differences, not data rows.
A zero exit code is necessary but **not sufficient** for production adoption:
the capture must be demonstrably complete, with expected counts (**107
tables, 946 columns, 127 foreign keys, 52 CHECKs**) and a separate review of
MariaDB version, default schema collation, charset, identifier visibility,
`schema_migrations` history and `flyway_schema_history` presence/absence.
The environment context is intentionally **excluded** from the structural hash.

No automatic normalization of genuine drift, no Flyway `repair`, no
`baselineOnMigrate`, and no production `baseline` operation may follow
without fingerprint approval, backup/restore evidence, legacy-runner freeze,
operator readiness, and separate written authorization. Record only sanitized
results and checksums in a future release evidence document.

## Version alignment and verified candidate

The current proposal is `B20261020_001__adopt_production_schema.sql`:
version `20261020.001`. In an **empty** database, Flyway runs this B
migration and skips earlier V scripts. In an **existing** database, adoption
must use an explicit `baseline` operation at the matching version **without**
running the creation SQL. `baselineOnMigrate` remains disabled.

This phase does not provide a production wrapper, credentials, a maintenance
window, live structural fingerprint or approval to execute adoption. The
offline DDL-equality utility verifies the source export; it is not a
replacement for a current live `information_schema` comparison.

## Conceptual sequence

1. Freeze schema changes and deployments.
2. Capture a new read-only structural fingerprint.
3. Compare it with the approved adoption package.
4. Abort on any difference.
5. Confirm backup and restoration evidence.
6. Confirm the restricted wrapper target and artifact identity.
7. Execute the approved baseline operation through the wrapper.
8. Confirm that only Flyway history metadata was introduced.
9. Validate Flyway history and the application-schema fingerprint.
10. Confirm API and Discord continue operating unchanged.
11. Record operator, timestamps, checksums, and results.
12. Reopen deployment activity.

## Abort conditions

- wrong or ambiguous database target;
- table count or fingerprint mismatch;
- unexpected Flyway history already present;
- legacy runner invocation cannot be ruled out;
- backup/restore evidence missing;
- runtime DDL observed during the window;
- any proposed operation would recreate an existing object.

## Recovery concept

The baseline operation should not alter application tables. On failure:

- stop and preserve logs/evidence;
- do not continue to the first versioned migration;
- inspect Flyway metadata and actual schema separately;
- do not use automatic repair;
- reconcile metadata only after human review.

## Completion criteria

- one explicit baseline record exists;
- application schema fingerprint is unchanged;
- legacy `schema_migrations` remains unchanged;
- no versioned migration was applied;
- API and Discord health checks pass;
- adoption evidence is archived without secrets.
