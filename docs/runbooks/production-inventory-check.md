# Comparing a private production schema export with the ownership catalog

> **Read-only/offline validation only.** No production connection, SQL execution,
> migration, data import, baseline adoption or deployment is part of this process.

## Evidence and scope

The latest owner-provided, structure-only `coddy` SQL export contains **107**
unique `CREATE TABLE IF NOT EXISTS` definitions. After inventory reconciliation,
`ownership/tables.yaml` also declares **107** tables, including 14 entries that
were missing in the October 2 inventory. All 93 pre-existing records were kept.

Do not infer that the current physical schema is completely reproduced by
`flyway/sql/versioned/`: this repository does **not** yet have a canonical
fresh-install baseline or verified `flyway_schema_history` in production.

## Operator procedure (read-only)

1. Export **schema/structure only**, explicitly selecting the intended
   database. Use a read-only database account. Do not include INSERT records,
   events, routines, credentials or data.
2. Keep the private SQL file **outside the repository**, git working tree, CI,
   PRs and public artifact storage. No database access is required to compare it.
3. From the Database repo root, with the pinned Python dependency installed:

   ```bash
   python -m pip install -r validation/requirements.txt
   python validation/scripts/validate_ownership.py
   python validation/scripts/reconcile_schema_inventory.py "/private/path/structure.sql"
   ```

4. The checker reports table **names and counts only**. Exit status 0 means
   exact name-set match; 1 means a difference or duplicate; 2 means invalid
   input or no table definitions. Confirm that the count is nonzero and matches
   the intended database before treating the result as meaningful.

**Security:** The script never executes SQL or prints row contents. It reads
the export locally, so the operator still must store and handle the dump
privately. This is a table-name comparator, not a complete SQL parser or a
structural equivalence guarantee.

## Actual isolation and source contracts for the 14 catalog additions

- **Backup** (4): `backup_guild_locks`, `backup_operation_steps`,
  `backup_restore_operations`, `backup_snapshot_operations`. These are
  guild-scoped. Operation steps carry a polymorphic operation ID without a
  physical FK; restore/snapshot rows have an unchecked physical `backup_id`
  relationship. API and Coddy must enforce same-guild access.
- **Temporary themes** (9): `discord_themes`,
  `discord_theme_active_guilds`, `discord_theme_applications`,
  `discord_theme_application_snapshots`, `discord_theme_assets`,
  `discord_theme_guild_locks`, `discord_theme_operations`,
  `discord_theme_operation_steps`, `discord_theme_resource_changes`.
  Some rely on a parent `theme_id`/`application_id` FK rather than a
  local `guild_id` column. Consumers must resolve the parent tenant and
  filter/authorize it; several other relationships do use composite guild FKs.
- **Portaria** (1): `portaria_bypasses`, keyed by
  `server_guild_id` and either a user ID or invite code. The two distinct
  target shapes are checked by the database; Coddy controls their runtime use.

Source evidence: owner-provided `Coddy(1).sql` (private, not versioned),
`V20261006_007`, `V20261007_002`, `V20261007_003`,
`V20261007_004`, current API `BackupControlPlaneStore`/
`ThemeControlPlaneStore` and Discord `core/database.py`.
The `current_ddl_owner` manifest field identifies the canonical versioned
DDL *source*, **not proof** Flyway executed it on production.

## Gate for structural parity and baseline

The 107-name inventory passing does not verify column types, generated fields,
defaults, nullability, collation, constraints, indexes, tenant semantics or
MariaDB compatibility. Before implementing the official baseline:

1. Produce a sanitized, normalized metadata fingerprint from a **new**
   read-only `information_schema` audit.
2. Verify physical columns, indexes/FKs, defaults, CHECKs and generated
   columns across the **entire** production schema, not just the 14 additions.
3. Reconcile drift between legacy/manual migrations, versioned SQL and actual
   schema; test new-db creation and upgrade with synthetic fixtures.
4. Validate N/N-1 API and Discord compatibility and isolation on a disposable
   MariaDB 10.6 database.
5. Prepare restricted operator workflow, backup recovery plan and separate
   authorization for production adoption. Do not use `baselineOnMigrate`,
   `repair` or `clean` as an automatic shortcut.

Follow [Database issue #6](https://github.com/BraFurries/BraFurries-Database/issues/6)
for the remaining baseline/rollout requirements.
