# Membership presence and ban revocation expansion

## Status

This is an approved **manual additive DDL** proposal. Phase 2 has no official Flyway baseline/history, so no `B`, `V`, or `R` migration is committed.

## Preconditions

An operator must compare the target tables and `users.id` type against safe, read-only schema evidence before execution. This task neither accesses production nor executes DDL.

## Manual DDL

```sql
ALTER TABLE user_community_status
    ADD COLUMN is_present TINYINT(1) NULL DEFAULT NULL,
    ADD COLUMN left_at DATETIME NULL DEFAULT NULL;

ALTER TABLE user_bans
    ADD COLUMN revoked_at DATETIME NULL DEFAULT NULL,
    ADD COLUMN revoked_by INT NULL DEFAULT NULL,
    ADD COLUMN revocation_reason VARCHAR(512) NULL DEFAULT NULL,
    ADD CONSTRAINT fk_user_bans_revoked_by
        FOREIGN KEY (revoked_by) REFERENCES users(id)
        ON UPDATE RESTRICT ON DELETE SET NULL;
```

No speculative secondary index is requested. The foreign key may create its supporting index according to MariaDB behavior.

## Semantics and rollout

- `NULL/NULL` is presence unknown; `TRUE/NULL` is present; `FALSE/<time>` is an observed leave; `FALSE/NULL` is a reconciled legacy absence with unknown leave time.
- `member_since` is never reset. First-known values derive from the lowest `member_since`, then `community_id`.
- A ban is revoked when `revoked_at` is non-null, otherwise expired when `valid_until` is before today, otherwise active.
- Existing rows remain `NULL/NULL`; no global backfill is permitted.

Apply the manual Database expand first, then compatible Discord/API readers-writers, then Front. Application rollback leaves the nullable expansion compatible with N-1. A reconciliation caller must establish a complete guild member view before recording absence; cache misses are not evidence.
