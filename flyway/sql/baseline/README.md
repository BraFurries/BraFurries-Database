# Candidate structural baseline (not production-adopted)

The canonical candidate is **`B20261020_001__adopt_production_schema.sql`**,
Flyway version **`20261020.001`**.

It creates 107 tables (946 columns, 127 foreign keys, 52 CHECK constraints,
105 PKs, and 3 generated columns) from the updated owner-provided **structure-only**
MariaDB export, with dependency-safe ordering and without source database names,
data/INSERT statements, or production AUTO_INCREMENT counters.

## Two separate Flyway mechanisms

1. **Empty/new databases:** Flyway `migrate` selects the latest B baseline
   migration and skips all historical V scripts at or below its version.
   `validation/scripts/baseline_smoke_test.py` proves this on disposable
   MariaDB 10.6 (including `validate` and a repeated migrate).
2. **Existing production database:** the SQL must **never** be executed over
   existing tables. In a separately approved, controlled adoption, Flyway's
   explicit `baseline` command records **only history metadata** at exactly
   version `20261020.001` after comparing current normalized physical schema
   to the approved fingerprint. `baselineOnMigrate` stays false.

These are not interchangeable. A B migration is **not** an instruction to run
`migrate` against a populated database without Flyway history.

## Evidence boundaries

- Full DDL equivalence with the latest external schema export can be checked
  offline with `python validation/scripts/compare_baseline_ddl.py
  "/private/path/schema.sql"`. The private export is never committed to the
  repository/CI and the command prints only table names and digests.
- The source-export normalized structural digest at selection:
  `55078b06240d6164e605ae15967d0fc697b312a4d0113082a0db6c87018aadd7`.
  It is a file-to-baseline **DDL digest**, not a live `information_schema`
  fingerprint or attestation of reference-data completeness.
- Legacy `schema_migrations` is preserved as an empty table on fresh install.
  Its actual rows, seeded configuration/reference data and production Flyway
  metadata must be assessed separately.
- No production connection, API/Coddy execution, credentials, wrapper, job or
  deployment is introduced by this baseline candidate.

For approval requirements and abort conditions, see
[production baseline adoption](../../../docs/runbooks/baseline-adoption.md).
