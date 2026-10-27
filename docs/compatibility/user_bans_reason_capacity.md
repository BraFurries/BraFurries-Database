# User ban reason capacity and repeated-reason compatibility

## Problem

The production-adopted baseline uses `user_bans.reason VARCHAR(256)` and
`UNIQUE unique_ban (community_id, date, reason)`. A legitimate detailed reason
longer than 256 characters can raise `DataError`. Two different users in the
same Community with the same ban reason and date may also collide, even though
they represent separate moderation actions.

The primary key `user_bans.id`, rather than a shared human-readable reason,
identifies a moderation action. Existing `user_ban_discord_effects.ban_id`
references continue to work.

## Migration

`V20261027_003__expand_user_ban_reasons.sql`, owned by Database:

- widens `reason` to `VARCHAR(2048) NOT NULL`;
- removes the semantically incorrect `unique_ban` constraint;
- adds non-unique `idx_user_bans_community_date (community_id, date)`
  for existing date/community lookups and the Community foreign key;
- preserves rows, original IDs, and all Discord-effect foreign keys.

No Coddy/API runtime DDL or production data backfill is permitted. Keep the
historical baseline unchanged.

## Preconditions and rollout

1. Read-only production preflight: `SHOW CREATE TABLE user_bans`,
   `SHOW INDEX FROM user_bans`, `SHOW COLUMNS FROM user_bans`, and Flyway
   history. Compare live structure to the adopted baseline; do not assume
   the baseline has already been applied or that the new version is present.
2. Apply Database migration through the established controlled Flyway rollout;
   confirm `reason` length 2048, no `unique_ban`, and a non-unique
   `idx_user_bans_community_date`. Verify row count and dependent FK health.
3. Deploy API mapping widening (`@Column(length = 2048)`), preserving
   `LocalDate` for `date` and `valid_until`.
4. Deploy Coddy 2048-character input validation and DATE-binding fix.
5. Smoke one permanent ban with a short reason, one long reason, and separate
   users with the same reason, **only with authorized test accounts**. Confirm
   records before effects and audit outcomes. Do not rerun real ban commands
   to test a schema migration.

## Compatibility and limitations

- Older API/Coddy versions remain able to read/write existing short reasons
  during a staged rollout.
- A pre-migration Coddy configured to accept 2048-character reasons will
  fail at the old 256-character column; **migrate Database first**.
- The `date` and `valid_until` columns remain SQL `DATE`; hourly
  expiration needs its own coordinated Database/API/Coddy migration.
- In case of rollback, do not shrink the field to 256 if long reasons already
  exist; preserve data and roll back application deployments first.
- Logging raw reasons or SQL parameter tuples is prohibited; log sanitized
  MariaDB `errno`, `sqlstate`, and guild identifier instead.
