# Production schema vs ownership catalog — 19 October 2026

> **Read-only reconciliation / no production operation.**
> Evidence: no-data MariaDB 10.6 structural export supplied by the owner on
> 2026-10-19, and the repository contents checked at the SHAs below.
> Do not commit the original dump, extrapolate row counts, infer that Flyway
> already ran, or treat this document as an executable baseline.

## Revisions and observed scope

- Database `main`: `c6f5fac9471b9a608546bab52bbad116a1986f4a`.
- Coddy `main`: `e701680e857479403492012d30ff658f36069c6b`
  (PRs #29–#32 merged and all four subsequent production deployments succeeded).
- Source snapshot: schema only (tables, columns, indexes and constraints, not
  data rows, grants, live server status, or migration execution provenance).
- Counted `CREATE TABLE IF NOT EXISTS` definitions in the export: **101**.
- `ownership/tables.yaml` contains **93** entries
  (`table_count_expected: 93`). Both figures were enumerated by name,
  not inferred from the difference in counts.

### Missing from the governance manifest (in the export)

These 13 names appear in the 101-table export but not in the 93-table
ownership manifest. They must be classified using their canonical migrations,
actual API/Coddy consumers and tenant key semantics; their names alone do
not establish which service owns their business rules.

| Family | Objects missing from manifest |
| --- | --- |
| Backups | `backup_guild_locks`, `backup_operation_steps`, `backup_restore_operations`, `backup_snapshot_operations` |
| Temporary themes | `discord_theme_active_guilds`, `discord_theme_application_snapshots`, `discord_theme_applications`, `discord_theme_assets`, `discord_theme_guild_locks`, `discord_theme_operation_steps`, `discord_theme_operations`, `discord_themes` |
| Portaria | `portaria_bypasses` |

The Database repository already contains relevant versioned SQL, including
`V20261006_007` (Portaria), `V20261007_002` and `V20261007_003`
(backups) and `V20261007_004` (themes). **Presence in the repository is not
proof Flyway executed any of these versions in production.**

### Catalog-only names (not in this export)

The following five entries appear in the manifest but not in the
2026-10-19 export: `event_scheduling`, `event_staffs`,
`event_transfer_logs`, `event_transfer_requests`, `events`.

Do **not** drop these entries or automatically create tables. Determine
whether these are retired historical tables, migrated elsewhere, from a
different database/schema, or genuine schema drift. Preserve audit history
and unknown status until evidence resolves the discrepancy.

### Why the simple 101 − 93 = 8 comparison is misleading

It conceals two different lists. Precisely **13** production-only names and
**5** catalog-only names yield the net difference of eight. Updating only the
expected count would make the validator pass without fixing the inventory.

The earlier 78-table statements in older ADRs/runbooks are historical and
must not be used as the expected 2026-10-19 production table count.

## Coddy runtime DDL result

A source audit of the 79 non-test Python files on Coddy main `e701680`
found no explicit `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE`,
`DROP INDEX` or `RENAME TABLE` SQL sites. The known 13 sites in
`core/database.py` were retired in PRs #29–#32 and the XP cog mutations
in earlier deliveries. The deployed final image was healthy and 735
tests passed on the combined main.

Dynamic SQL exists, but the reviewed examples assemble **SELECT** or
**UPDATE/INSERT** statements, not schema mutations (e.g.
`core/database.py::getConfig` constructs a SELECT column list from metadata;
`updateServerConfig` constructs an UPDATE SET clause).

This is **static/code-path evidence only**, not formal runtime observation of
all inputs, indirect SQL execution, stored procedures or database privileges.
Any untrusted SQL construction or tenant authorization vulnerabilities should
be tracked separately from DDL retirement.

## Flyway adoption blockers

1. **No baseline exists:** `flyway/sql/baseline/` contains no approved
   baseline SQL; versioned SQL alone cannot build the complete historical
   application schema on a fresh database.
2. **No proven Flyway production history:** the supplied export contains
   legacy `schema_migrations`, not `flyway_schema_history`. The absence in
   this dump cannot substitute for read-only production verification immediately
   before adoption.
3. **No safe baseline version selected:** older versioned migrations may
   already be represented in production via manual/transitional rollout.
   Never apply historical `V...` scripts blindly over existing objects.
4. **Catalog drift:** 13/5 mismatches above, including ownership and tenant
   semantics requiring review.
5. **Operational gate not implemented:** the production-only restricted
   wrapper, dedicated credential, approved fingerprint, tested restore,
   maintenance window and legacy runner-invocation evidence remain outstanding.
6. **No-data export limitations:** it proves no cardinalities, existing
   reference rows, historical uniqueness, data integrity or column-level
   compatibility with current writers under real data.

## Required next work (separate deliverables)

1. **Governance PR:** reconcile each of the 13 newly observed objects into
   `ownership/tables.yaml` using canonical versioned DDL and verified
   ownership/tenant semantics. Retain the five historical-only entries
   pending explicit classification; do not disguise the difference by
   merely changing `table_count_expected`.
2. **Offline fingerprint:** obtain a fresh sanitized structure-only snapshot,
   normalize identifiers/types/defaults/constraints, compare each expected
   table and produce a reviewed schema fingerprint/checksum. Do not publish
   raw exports or credentials.
3. **Baseline design:** propose the one-time explicit baseline version,
   independent fresh-database representation, order of historical versions,
   and N/N−1 compatibility. Review whether the selected Flyway edition,
   baseline file format and actual version ordering support the plan.
4. **Disposable validation:** build a **fresh** MariaDB 10.6 database and an
   **upgrade/adoption fixture** reproducing the approved existing shape,
   validate full Flyway history/checksums, API JPA projections, Coddy preflight,
   tenant constraints and synthetic anomalies. The current smoke test validates
   an isolated fixture, not the full 101-table production baseline.
5. **Operational rollout, only after specific authorization:** confirm backup
   restoration, restricted migration wrapper/credential, live read-only
   fingerprint, exclusive schema-change window, absence of legacy runners,
   manual explicit Flyway baseline (not `baselineOnMigrate`), postconditions,
   API/Coddy health, and recorded evidence. Never auto-execute historical
   versioned DDL during the adoption operation.

## Legacy `schema_migrations`

Keep the table and its rows unchanged as historical evidence. Do not translate
them into `flyway_schema_history`, reset them, rename them, or drop them.
The current public Coddy tree contains no `scripts/run_migrations.py` path;
whether an external host wrapper or an older deployment invokes it must still
be verified by operations. This observation is not proof about production
processes.

## Decision for this slice

**No production baseline, schema DDL/DML, or manifest rewrite is approved by
this audit.** The schema authority remains Database, while API handles
administrative policy and Coddy handles observed network runtime effects.
Keep [Coddy issue #3](https://github.com/BraFurries/BraFurries-Discord/issues/3)
open until the above evidence and operational migration path are complete.
