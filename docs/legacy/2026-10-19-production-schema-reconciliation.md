# Reconciliation of production structural exports and schema ownership catalog

> **Historical snapshot:** this report describes the pre-reconciliation state when the manifest had 93 entries. The 14 missing entries are now proposed in the 2026-10-20 catalog PR; use [the current inventory runbook](../runbooks/production-inventory-check.md) for the updated 107/107 table-name comparison. No baseline or physical schema parity is implied.

> **Source correction — no production operation.** This document supersedes the
> preliminary 101-vs-93 analysis in the initial draft of PR #5. It compares
> two distinct user-provided no-data SQL exports and the current ownership
> manifest. Do not infer that omitted tables were absent from the live database,
> and do not commit either raw export to this public repository.

## Audited references

- Database `main` at the initial audit: `c6f5fac9471b9a608546bab52bbad116a1986f4a`.
- Coddy `main`: `e701680e857479403492012d30ff658f36069c6b`.
- Earlier SQL export supplied in the project: **101 unique `CREATE TABLE` definitions**.
- **New** SQL export supplied by the owner (`Coddy(1).sql`):
  **107 unique `CREATE TABLE IF NOT EXISTS` definitions** (no duplicate table names).
- `ownership/tables.yaml`: **93** entries (`table_count_expected: 93`).
- Comparison uses **exact table names**, not net totals or arbitrary page limits.
  Both exports are structural evidence; no table contents, production connection,
  executable baseline or Flyway history was audited here.

## Correct result from the new 107-table export

**All 93 cataloged tables appear in the current user-provided export.**

- Catalog entries missing from the new export: **0**.
- Exported names not yet covered by the catalog: **14**.
- Net difference: **107 − 93 = 14**, all on the manifest side.

### Names present in the new export but absent from the manifest (14)

| Area | Tables | Count |
| --- | --- | ---: |
| Backups | `backup_guild_locks`, `backup_operation_steps`, `backup_restore_operations`, `backup_snapshot_operations` | 4 |
| Temporary themes | `discord_themes`, `discord_theme_active_guilds`, `discord_theme_applications`, `discord_theme_application_snapshots`, `discord_theme_assets`, `discord_theme_guild_locks`, `discord_theme_operations`, `discord_theme_operation_steps`, `discord_theme_resource_changes` | 9 |
| Portaria | `portaria_bypasses` | 1 |

The repository already contains versioned SQL related to these structures,
including `V20261006_007`, `V20261007_002`, `V20261007_003`, and
`V20261007_004`. A tracked migration script does **not** prove Flyway
applied that version to the live database.

### What made the earlier comparison misleading?

The earlier 101-table export did not contain these **six** definitions,
all of which are present in the newly supplied 107-table export:

- `events`
- `event_scheduling`
- `event_staffs`
- `event_transfer_logs`
- `event_transfer_requests`
- `discord_theme_resource_changes`

The preliminary report counted 13 export-only names and five manifest-only
names against **that earlier file**, leading to a misleading explanation
that event tables might be missing from production. The owner challenged
that premise and supplied a new export that resolves it: all five event
tables exist in the **new structure-only export**. The old export's omission
does **not establish** that the tables were ever absent from the running
database; export filters, export scope and timing have not been verified.

**Do not create event tables, drop any object, remove manifest entries, or
apply any migration merely to reconcile these snapshots.** The observed
governance gap is that 14 already-exported tables are not classified in the
ownership manifest. These are not missing from production.

## Follow-up in BraFurries-Database

1. Extend the ownership manifest with the **14 real tables** from the new
   export after reviewing their canonical migrations, runtime readers/writers,
   key semantics and tenant isolation. Do not simply change
   `table_count_expected` without actual entries.
2. Preserve the 93 existing entries, including the five event tables.
3. Confirm on the actual target via a **future authorized, read-only**
   `information_schema` export with explicit schema selection that the
   expected table inventory and fingerprint match. Capture full column,
   index, foreign-key, nullability, default and charset metadata.
4. Design a **separate explicit** Flyway baseline version and fresh-database
   representation; the existing 2026 versioned migrations must not be
   replayed blindly on production. Version-control SQL alone is not
   `flyway_schema_history`.
5. Preserve `schema_migrations` as historical evidence; do not import,
   rename, clean or repair Flyway history automatically. Check external
   legacy-runner invocation separately.
6. Validate proposed baseline/upgrade behavior on disposable MariaDB 10.6,
   including API compatibility, Coddy preflight and tenant constraints,
   before requesting a production adoption plan.

## Coddy runtime DDL status (separate workstream)

Coddy `main` at `e701680` has no explicit literal CREATE/ALTER/DROP/
RENAME/TRUNCATE TABLE/INDEX sites in the reviewed 79 runtime Python files
after PRs #23–#32. Static inspection is **not** a guarantee against SQL
constructed entirely from dynamic input, external scripts or stored
procedures. A regression guard is proposed in Coddy PR #33.

## Operational prohibition

**This document is not an executable Flyway baseline or permission to touch
production.** No database DDL, DML, migrations, grant changes or production
deploys are included in this documentation PR. Adoption still requires a
validated fingerprint, compatible test fixtures, backup/restore evidence,
restricted migration credential/wrapper, maintenance plan and explicit owner
authorization. Track the catalog/baseline work in Database issue #6, and the
runtime authority in Coddy issue #3.
