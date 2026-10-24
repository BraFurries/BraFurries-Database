# Transitional release record: Recruitment V1 schema (2026-10-24)

## Status / evidence boundary

The operator reported executing all **14 reviewed recruitment versioned SQL scripts**
against the existing MariaDB production schema **manually**, outside the
BraFurries-Database/Flyway runtime. The operator provided read-only HeidiSQL
results showing **124 application tables**, of which **17** are named
`recruitment_*`, matching the expected count (107 legacy + 17 recruitment).

**This is operator-reported evidence, not independently verified database access.**
Table counts do not validate every FK, CHECK, column or execution history. The
screenshots did not establish restoration of the backup, an operational Flyway
baseline, a completed application deployment, or activation of the feature.

## Schema authority

The authoritative release artifact is exactly this repository's versioned SQL:

- `V20261021_001` (recruitment foundation);
- `V20261022_001` through `V20261022_004` (draft revisions, submissions,
  human review, stage decisions);
- `V20261023_001` through `V20261023_009` (voting, attempts, objective scoring,
  score publication, integrity events, reinstatement, autosave and notifications).

The scripts create **17 recruitment tables** and extend recruitment-owned
tables. No change to any legacy application table was intended. Production
schema was modified **manually by the operator**; no API/Coddy DDL is authorized.

## Flyway history is not an installation record

The SQL executed manually does **not** create
`flyway_schema_history` or mark the 14 versions applied. The pre-adoption
production schema was reported without a Flyway history table. **Before ever
using Flyway `baseline`/`migrate` against this production database**, reconcile
all already-applied post-`20261020.001` versions against their actual physical
effects and design a separately reviewed adoption plan that **will not replay
these DDLs**. Blind `migrate` after baseline would attempt to recreate the
17 tables or duplicate columns/constraints. Do not forge Flyway rows or
use `repair` as a substitute for proper history migration.

There is no authorization here to apply any further DDL, DML, `baseline`,
`migrate`, `repair` or `baselineOnMigrate` in production.

## Follow-up

- Verify table/column, FK, index and CHECK structure using read-only metadata
  against the approved 124-table reference. The 14 canonical migration files
  define **32 distinct new foreign-key constraints** and **43 distinct final
  recruitment CHECK constraints** (44 CHECK additions, including a replacement
  of `ck_rsd_source`). These counts are **expectations from the SQL files**,
  not observed production metadata. A read-only operator may inspect them with:

  ```sql
  SELECT
    (SELECT COUNT(*)
       FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_TYPE = 'BASE TABLE'
        AND LEFT(TABLE_NAME, 12) = 'recruitment_') AS recruitment_tables,
    (SELECT COUNT(*)
       FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_SCHEMA = DATABASE()
        AND CONSTRAINT_TYPE = 'FOREIGN KEY'
        AND LEFT(TABLE_NAME, 12) = 'recruitment_') AS recruitment_fk_constraints,
    (SELECT COUNT(*)
       FROM information_schema.CHECK_CONSTRAINTS
      WHERE CONSTRAINT_SCHEMA = DATABASE()
        AND LEFT(TABLE_NAME, 12) = 'recruitment_') AS recruitment_check_constraints;
  ```

  Expected: 17, 32, 43. Investigate any difference; matching counts alone
  do not establish equality of individual definitions.
- Confirm the official BraFurries Community ID from the active Discord guild
  `753321055682035712` (never guess the numerical Community ID).
- Deploy API and Front in authorized sequence and verify the feature is gated
  to that tenant, with no leakage or gabarito in candidate routes.
- Schedule the previously generated full backup's isolated restore test in
  the later Database operationalization phase; do not claim it was tested.
- Keep private dumps, production data and credentials out of GitHub.
