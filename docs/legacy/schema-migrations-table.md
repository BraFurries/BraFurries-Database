# Legacy `schema_migrations` table

## Classification

- Status: `LEGACY_MIGRATION_HISTORY`
- Domain owner: infrastructure/legacy Discord runner
- Future schema authority: BraFurries-Database
- Historical reader/writer: legacy Discord migration runner. The current public `BraFurries-Discord` tree does **not** contain `scripts/run_migrations.py`. External/old host invocation remains unverified and must be checked operationally.

## Purpose

The table stores Discord migration file names and their application timestamps. It is not a complete historical representation of how the current production schema was created.

## Approved treatment

- Preserve the table during Phase 1 and Flyway adoption.
- Do not import its rows into `flyway_schema_history`.
- Do not rename it to the Flyway history table.
- Do not claim Flyway executed the recorded migrations.
- Capture its production contents read-only during a future approved baseline-preparation window.
- Keep it physically present until a separate retention decision is approved.

## Coexistence boundary

Temporary physical coexistence of `schema_migrations` and `flyway_schema_history` is acceptable. Concurrent versioning is not.

Once Flyway adoption occurs:

- Flyway is the only writer of new schema history;
- the old table is evidence only;
- the Discord runner must not publish new versions.

## Unknowns

- `TODO_HUMAN`: production rows are not available in the no-data dump.
- `TODO_HUMAN`: external deploy invocation of the runner must be confirmed.
- `TODO_HUMAN`: retention duration after runner removal.
