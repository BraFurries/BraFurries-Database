# Flyway layout

This directory is the official Flyway layout. It contains additive versioned history but no baseline or repeatable migration yet.

- `conf/` contains validation-only Flyway configuration.
- `sql/baseline/` is reserved for a separately approved executable baseline.
- `sql/versioned/` contains reviewed additive versioned migrations.
- `sql/repeatable/` is reserved for future repeatable migrations.

The executable smoke fixture lives under `validation/fixtures/`, outside this directory. It is test-only history and must never be copied into an official migration location.
