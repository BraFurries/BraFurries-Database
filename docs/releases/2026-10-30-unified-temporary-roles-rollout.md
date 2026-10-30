# Temporary Discord roles — unified ledger V1 (transitional production rollout)

Status: **schema SQL manually applied in production on 2026-10-30**. Operator reported postflight approval; application merges/deploys were still pending at that checkpoint. Do **not** run the migration again. Production Flyway history has not been adopted; preserve the manual pre-baseline exception.

## Scope and evidence

Database owns `V20261030_001__extend_user_temp_roles_for_manual_grants.sql`.
The existing `user_temp_roles` table remains the single ledger for `LEGACY`
rewards and `MANUAL` administrative grants. No shadow tables, flags or DDL in
API/Coddy. MariaDB 10.6.22 in production; server clock observed at UTC.

Operator's 2026-10-30 read-only sample: 15 grants; 15 unexpired, 0 expired,
0 invalid role IDs, 0 missing community or Discord identity link, 0 duplicate
`(disc_community_id,disc_user_id,role_id)` groups. The original table has
six columns: `id`, `disc_community_id`, `disc_user_id`, `role_id`,
`expiring_date` and `reason`. Screenshots of `SHOW CREATE TABLE` truncated
the DDL; key/index structure must still be independently reviewed.

`coddy.flyway_schema_history` **does not exist**, as anticipated by the
not-yet-adopted production Flyway baseline. Do not create it, invoke
`flyway baseline`, set `baselineOnMigrate`, or fake migration history.
Use only the canonical reviewed versioned SQL as the explicitly authorized
pre-baseline manual rollout; record evidence for that exception.

## Required stop/go preflight

- Confirm a fresh, restorable production backup **and a recovery operator**.
- Freeze competing schema changes and legacy Discord migration runner.
- Confirm production target `SELECT DATABASE(), VERSION(), UTC_TIMESTAMP()`.
- Compare full legacy `SHOW CREATE TABLE user_temp_roles` to the reviewed
  baseline, especially PK, FKs, column types and nullable constraints.
- Confirm `community_discord` has the composite key on
  `(community_id,guild_id)` and the expected unique guild binding.
- Confirm all existing rows join both parent tables and no NULL key
  backfill is needed; capture pre-migration count (15 as of evidence date).
- Confirm API/Coddy/Front artifacts and approvals before starting a
  migration with potential metadata locks. Do not assume DDL transaction
  rollback; stop and inspect the current schema after any partial failure.
- Recheck PR HEAD/CI/mergeability/reviews before each merge.
- Do not run synthetic fixture DDL or the full historical Flyway scripts
  against the real database.

## Read-only last preflight

```sql
SELECT DATABASE() AS db, VERSION() AS mariadb_version,
       @@session.time_zone AS tz, NOW() AS now_server, UTC_TIMESTAMP() AS now_utc;

SELECT INDEX_NAME, NON_UNIQUE,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS key_columns
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='community_discord'
 GROUP BY INDEX_NAME, NON_UNIQUE ORDER BY INDEX_NAME;

SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME,
       REFERENCED_COLUMN_NAME
  FROM information_schema.KEY_COLUMN_USAGE
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='user_temp_roles'
 ORDER BY CONSTRAINT_NAME, ORDINAL_POSITION;

SELECT COUNT(*) AS legacy_rows,
       SUM(cd.id IS NULL) AS missing_community,
       SUM(ud.id IS NULL) AS missing_identity
  FROM user_temp_roles t
  LEFT JOIN community_discord cd ON cd.id=t.disc_community_id
  LEFT JOIN user_discord ud ON ud.id=t.disc_user_id;
```

## Transitional migration

After **explicit authorization and backup confirmation**, execute the
canonical three statements of the versioned migration exactly **once**,
in sequence: additive `ALTER TABLE`, legacy key backfill `UPDATE`, and
indexed/tenant-qualified constraint `ALTER TABLE`. The source of truth
is the file in the Database PR, not a separately hand-edited SQL copy.
MariaDB DDL commits independently; if a statement fails do not blindly
rerun the entire migration. No Flyway history row is created.

Existing rows have no reliable original creation/application timestamps:
the migration intentionally leaves `created_at`, `updated_at` and
`applied_at` NULL for the historical legacy rows. This is not an error.

## Postflight (read-only)

```sql
SELECT COUNT(*) AS ledger_rows,
       SUM(grant_source='LEGACY') AS legacy,
       SUM(grant_source='MANUAL') AS manual,
       SUM(grant_source='LEGACY' AND status='ACTIVE') AS legacy_active,
       SUM(grant_source='LEGACY' AND
           (community_id IS NULL OR guild_id IS NULL OR discord_user_id IS NULL))
         AS unbackfilled_legacy
FROM user_temp_roles;

SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='user_temp_roles'
ORDER BY ORDINAL_POSITION;

SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='user_temp_roles'
ORDER BY CONSTRAINT_TYPE, CONSTRAINT_NAME;

SELECT INDEX_NAME, NON_UNIQUE,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns_indexed
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='user_temp_roles'
GROUP BY INDEX_NAME, NON_UNIQUE
ORDER BY INDEX_NAME;

SELECT COUNT(*) AS unexpected_legacy_timestamps
FROM user_temp_roles
WHERE grant_source='LEGACY' AND
      (created_at IS NOT NULL OR applied_at IS NOT NULL);
```

Immediately after DDL, before new writes, expected: original 15 historical
rows remain, all classified `LEGACY`, zero `MANUAL`, no missing
backfilled guild/user IDs or fabricated historical dates. Do not interpret
different counts automatically as corruption if live Coddy writes in
parallel; use a controlled maintenance window and audit timestamps.

## Application rollout

Database schema **first**; after postflight, Coddy #47 (reconciler and
legacy writer adaptation), API #59 (authorization and control plane),
Front #42 (admin UI). No feature flag. Observe startup/readiness and
Discord permission errors. Use a controlled test guild to verify granting,
renewing, cancelling, expiration and preservation of unrelated/legacy
roles. Do not claim real Discord homolgation based on mocked tests.

Rollback: never delete the new schema fields or legacy records while any
application version can write them. First roll back application code to
a compatible reader if necessary, freeze writes and assess DB recovery
separately; restoring a whole production snapshot can discard later data.
