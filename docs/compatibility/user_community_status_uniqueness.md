# user_community_status — current membership uniqueness

Status: **official additive versioned migration, pending production application**.

## Domain rule

`user_community_status` represents the **current state** of one internal user inside one Community.

The canonical cardinality is therefore:

```text
UNIQUE (community_id, user_id)
```

This is not a membership-history table. Join/leave changes update the current row; historical events belong in dedicated history/audit structures.

## Production evidence and reconciliation

Read-only preflight on 2026-09-30 found one duplicated pair:

- `community_id=1`
- `user_id=1199`
- 21 rows
- IDs 1122..2385

Detailed inspection proved all state fields were equivalent and only `member_since` differed. No foreign key referenced `user_community_status.id`.

The operator preserved ID 1122 with the first-known `member_since=2025-08-13 12:28:50` and removed only the other 20 duplicates. A global duplicate query then returned zero rows.

The reconciliation is production evidence, not part of the migration SQL.

## Writer prerequisite

BraFurries-Discord#562 / PR #563 fixes `includeUser()` so membership creation is idempotent per user/Community.

Deploy that writer fix **before** applying this UNIQUE in production. Otherwise the legacy duplicate-username recovery path can attempt a second membership insert and fail on the new key.

## Canonical migration

`flyway/sql/versioned/V20260930_001__enforce_unique_user_community_status.sql`

The migration only adds:

```sql
UNIQUE KEY uk_user_community_status_community_user (community_id, user_id)
```

No DML or automatic duplicate cleanup is allowed.

## Compatibility

- Existing readers using `WHERE user_id=? AND community_id=?` become structurally aligned with the domain.
- Existing updates by that pair remain compatible.
- New duplicate inserts become explicit integrity errors instead of silent data corruption.
- The key can be referenced by tenant-aware foreign keys such as Community Team assignments.

## Rollout

1. deploy BraFurries-Discord#563;
2. re-run the global duplicate preflight and require zero rows;
3. apply this Database migration/approved manual equivalent;
4. verify the unique index exists;
5. continue with Community Team assignment schema.

Production baseline adoption remains a separate operation.
