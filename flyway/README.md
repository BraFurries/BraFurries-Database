# Flyway layout

This directory holds the candidate Flyway baseline `B20261020_001__adopt_production_schema.sql` plus reviewed additive versioned migrations. The baseline is for clean installations only; production has NOT been adopted or migrated.

- `conf/` contains validation-only Flyway configuration.
- `sql/baseline/` contains a sanitized, 107-table baseline candidate with version `20261020.001` (higher than all older V migrations), tested on disposable MariaDB. It is NOT a command to run on an existing database.
- `sql/versioned/` contains reviewed additive versioned migrations.
- `sql/repeatable/` is reserved for future repeatable migrations.

The executable smoke fixture lives under `validation/fixtures/`, outside this directory. It is test-only history and must never be copied into an official migration location.
