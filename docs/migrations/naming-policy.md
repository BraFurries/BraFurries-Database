# Migration naming policy

## Status

The naming policy applies to the official SQL history and the new 107-table baseline candidate. A baseline file is not approval to execute Flyway on production.

## Official locations

Future official SQL may exist only in the directory matching its Flyway type:

| type | location | filename |
|---|---|---|
| Baseline migration | `flyway/sql/baseline/` | `BYYYYMMDD_NNN__lower_snake_case.sql` |
| Versioned migration | `flyway/sql/versioned/` | `VYYYYMMDD_NNN__lower_snake_case.sql` |
| Repeatable migration | `flyway/sql/repeatable/` | `R__lower_snake_case.sql` |

`YYYYMMDD` is a real calendar date and `NNN` is a three-digit sequence from `001` through `999`. The Flyway version represented by a baseline or versioned filename is `YYYYMMDD.NNN` because underscores are version separators.

Descriptions use lowercase ASCII letters, digits, and underscores. Files cannot be nested below the type directory.

## Version allocation and concurrent development

1. Choose the intended integration date and the next unused sequence for that date.
2. Rebase or merge current `main` before requesting final schema review.
3. Run `python validation/scripts/validate_migrations.py --allow-official` to detect naming and version collisions.
4. If an unapplied migration collides, rename it on the feature branch and repeat validation before merge.
5. Never edit or rename a migration after it has been applied to a shared environment. Resolve later changes with a new version.

The future immutable-history gate requires a separately approved implementation. Phase 2 establishes naming, path, and uniqueness checks only.

## Reserved local-draft versions

The following versions belong to the four files classified `LOCAL_DRAFT / NOT_REMOTE` and are permanently rejected as official versions:

- `20260824.001`
- `20260824.002`
- `20260824.003`
- `20260824.004`

Their SQL is not imported, renamed, copied, or treated as official history.

## Baseline restriction

The 107-table candidate uses `B20261020_001__adopt_production_schema.sql` (version `20261020.001`), above the October 8 historical V scripts. A future production adoption must use the same approved baseline version via explicit `baseline` after a freshly verified physical fingerprint and a separately authorized maintenance window. `baselineOnMigrate` remains disabled.

## Smoke-fixture exception

`validation/fixtures/flyway-smoke/V00000000_001__create_brf_flyway_smoke_test.sql` is a test fixture, not an official migration. The impossible date `00000000`, isolated directory, synthetic table prefix, and Phase 2 validator prevent it from being confused with official history.
