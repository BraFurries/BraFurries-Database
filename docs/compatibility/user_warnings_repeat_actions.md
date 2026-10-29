# Warning persistence and same-day repeat actions

The adopted production baseline has `user_warnings.date DATE NOT NULL`,
`reason VARCHAR(1024) NOT NULL`, and
`UNIQUE unique_warning(user_id, community_id, date, reason)`.

That legacy unique key conflates genuinely distinct warnings for the same
member, Community and reason on the same calendar day. Warning actions are
identified by their primary key `id`; the rationale is not an idempotency key.

## Database migration `V20261029_003`

1. Add a nonunique index on `(community_id, user_id, date)` to retain efficient
   scoped member history queries.
2. Drop only `unique_warning`. Leave the warning primary key, author FK,
   Community FK, member FK and existing records untouched.
3. Preserve `DATE` and 1,024-character reasons so API/JPA projections,
   legacy history and Discord embed fields remain compatible.

## Runtime contract

- Manual `/warn` is an independent administrative action; two same-day
  occurrences with identical reasons must be recorded separately.
- `registerWarnIfAbsent` is a legacy import function and **must not**
  create duplicates on replay. Coddy locks the existing `users` parent row
  in the same transaction and checks for a matching member, Community, day
  and reason before inserting. The lock serializes concurrent imports without
  relying on uniqueness of human-readable reasons.
- Strict reasons must be nonblank and <= 1,024 Discord embed-field UTF-16
  units (including emoji); validate *before*
  Discord timeout effects. A warn with a mute must log the reason without
  adding a prefix that would exceed the embed field. Use Python `date`
  objects for DATE parameters.

## Rollout and safety

Verify the real `SHOW CREATE TABLE user_warnings`, `SHOW INDEX`, row counts
and Flyway history first. Apply Database migrations in version order
(`V20261029_002` for bans, then `V20261029_003` for warns).
Only then deploy the corresponding Coddy runtime version. API is read-only
for these warning schema changes; its `UserWarning` mappings remain intact.

Do not run live moderation commands against real members as migration tests.
Postflight checks should verify index changes, no lost records, and that
`user_warnings.reason` stays `VARCHAR(1024)`. Existing import historical
duplicates remain possible only across already stored records, which we
do not delete or deduplicate. Flyway history must not be fabricated manually.
