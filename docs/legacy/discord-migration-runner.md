# Legacy Discord migration runner

## Component

- Repository: `BraFurries-Discord`
- Path: `scripts/run_migrations.py`
- SQL location: `migrations/*.sql`

## Observed behavior

The runner:

1. loads Discord environment configuration;
2. connects directly to MariaDB;
3. creates `schema_migrations` when absent;
4. reads applied file names;
5. sorts local `*.sql` files;
6. skips file names already recorded;
7. splits SQL text on literal semicolons;
8. executes each fragment;
9. records the file name as the version;
10. commits once per file.

## Limitations

- no checksum;
- no protection against editing an already-recorded file;
- naïve semicolon splitting;
- no explicit cross-process migration lock;
- no target-schema fingerprint;
- rollback cannot reliably reverse MariaDB DDL;
- application repository owns shared-schema execution;
- environment loading makes operational boundaries difficult to audit.

## Known repository migration

The Discord repository contains one SQL migration that expands display-name columns in:

- `users`;
- `user_discord`;
- `user_telegram`.

The audited production schema reflects the expanded lengths. Because the production dump has no data, Phase 1 does not claim which `schema_migrations` row is present.

## Freeze policy

After adoption of this governance:

- no new migration may be added to the Discord runner;
- all new schema proposals belong in BraFurries-Database;
- the runner remains legacy-only until Flyway adoption and deployment-path verification;
- it must not run concurrently with Flyway.

## Retirement plan

1. Inventory any external deploy command that invokes the runner.
2. Capture the real `schema_migrations` rows read-only during baseline preparation.
3. Record the old migration file checksum and observed schema effect.
4. Confirm Flyway baseline covers the resulting state.
5. Operationally disable future runner use.
6. Observe multiple API/Discord deployment cycles.
7. Remove the runner in a later Discord PR.
8. Preserve legacy documentation and decide table retention separately.

Phase 1 performs none of these operational steps.
