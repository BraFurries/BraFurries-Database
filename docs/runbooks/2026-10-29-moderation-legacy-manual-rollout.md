# 2026-10-29 moderation schema transition — operator-applied, partial postflight confirmed

> On 2026-10-29, the operator **reported manual application** of V20261029_002,
> V20261029_003, and V20261029_004 to production. Read-only postflight
> screenshots confirm the expected columns and replacement indexes. This is
> evidence supplied by the operator, **not** an independently executed migration
> or a verification of all foreign keys, backups and historical records.
> Do not re-run these DDL scripts on the same schema. See the release evidence
> in `docs/releases/2026-10-29-moderation-manual-schema-transition.md`.

## Confirmed, read-only production observations

On 2026-10-29, the owner supplied a read-only HeidiSQL preflight:

| Check | `user_bans` | `user_warnings` |
|---|---|---|
| `reason` | `varchar(256) NOT NULL` | `varchar(1024) NOT NULL` |
| `date` | `DATE NULL DEFAULT current_timestamp(0)` | `DATE NOT NULL` |
| `applied_by` | `int(11) NULL` | `int(11) NOT NULL` |
| Legacy unique key | `unique_ban(community_id,date,reason)` | `unique_warning(user_id,community_id,date,reason)` |
| Replacement nonunique index | not yet present | not yet present |

The `flyway_schema_history` table **does not exist** in the inspected schema.
This is consistent with production Flyway adoption being pending. It must not be
interpreted as proof that earlier versioned SQL never ran manually.

For operational comparison only, one earlier preflight screenshot counted 67 bans and 317 warnings. The later postflight has 67 bans and 347 warnings, and the owner reports that 347 appeared in other earlier captures. These snapshots are insufficient to infer a migration-related warning increase or loss. No automatic anomaly is asserted.
No record contents, moderators, guild IDs, or private reasons belong in this
public runbook. Preserve all data and the nullable legacy columns.

## Execution model

Database README permits a transitional **manual mirror of reviewed, versioned
migrations** before production Flyway adoption. This is not `flyway migrate`,
`baselineOnMigrate`, `repair`, or creation of a fabricated history table.

The schema authority is the SQL already merged in `main`, in this exact order:

1. `flyway/sql/versioned/V20261029_002__expand_user_ban_reasons.sql`
   (create replacement index, drop `unique_ban`, widen ban reason to 2048)
2. `flyway/sql/versioned/V20261029_003__allow_repeated_user_warnings.sql`
   (create replacement index, drop `unique_warning`)
3. `flyway/sql/versioned/V20261029_004__add_user_ban_reason_details.sql`
   (add `reason_details VARCHAR(2048) NULL`; preserve old records)

**Do not paste partial or hand-edited DDL.** The SQL must match the reviewed
migration text exactly. Run the operations only after comparing the real
`SHOW CREATE TABLE` output, index/FK dependencies, MariaDB version and all
other outstanding production schema changes. MariaDB DDL commits implicitly,
so do not count on transaction rollback for a partially completed migration.

The **physical capacity** of `user_bans.reason` becomes 2048 characters.
The **new Coddy user input limit** is **512 URL-encoded UTF-8 characters**, because the same mandatory short
reason is sent to the native Discord audit log and the ban log embed.
An optional `reason_details` up to 2048 database characters contains staff-only
context; it must never be included in audit log headers, embeds or member DTOs. A longer reason must be rejected before
persistence/effects; no silent truncation or data-capacity shrink is planned.
The API JPA `@Column(length=2048)` describes the physical column capacity.

## Preconditions for a manual rollout (historical checklist)

- Verify selected database, MariaDB version and `SHOW CREATE TABLE` for both
  tables, including dependent FKs, engine and collation.
- Confirm `flyway_schema_history` is absent and review manual migration
  evidence for this schema. Confirm neither of the two migrations was
  previously applied under another name or by hand.
- Record before row counts, key names/columns, reason column sizes/nullability,
  parent-FK health and an approved backup recovery point.
- Arrange a maintenance window and prevent concurrent administrative writes
  while applying the two changes.
- Obtain separate owner authorization to execute the Database SQL.

## Postflight (read only; observed on 2026-10-29)

- Confirm `user_bans.reason VARCHAR(2048) NOT NULL`, `user_bans.reason_details
  VARCHAR(2048) NULL`, `user_warnings.reason VARCHAR(1024) NOT NULL`.
- Confirm both old unique keys are gone and the two new tenant-scoped indexes
  exist, **nonunique**, with the expected ordered columns.
- Confirm original PK/FK relationships remain, without modifying existing
  `date` or `applied_by` nullability. Column nullability was verified; full
  FK/constraint DDL remains unverified because the owner screenshots truncated
  `SHOW CREATE TABLE` text. Do not claim full parity until it is reviewed.
- Preserve before/after metadata and backup reference privately; record a
  sanitized release result under `docs/releases/` only **after** completion.

## Runtime deployment dependencies

After confirmed database postflight and authorized rollout: integrate API #55 (JPA short reason and optional private details) and the Coddy fixes #39/#40/#41. Coddy #42 is a draft integration PR combining their code without affecting `main`. Review actual PR diffs, HEADs, approval threads, mergeability
and checks again before any authorized merges, including CI on the final
combined Coddy main tree. Front and other tenants receive no new DDL.

Only authorized test accounts may be used for live moderation smoke tests;
never reapply real moderation sanctions simply to test a migration.
