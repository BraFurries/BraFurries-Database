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
