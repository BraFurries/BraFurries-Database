# Release evidence: manual moderation schema transition (2026-10-29)

## Scope and authority

The operator reported applying the exact structural changes represented by:

- `V20261029_002__expand_user_ban_reasons.sql`
- `V20261029_003__allow_repeated_user_warnings.sql`
- `V20261029_004__add_user_ban_reason_details.sql`

This was a **manual production action**, not performed by GitHub CI or the
assistant. Production still had no `flyway_schema_history` in the
earlier operator preflight; this release record **does not** create Flyway
history or assert completed production baseline adoption. #36 is still a
pending Database PR at the time of recording.

## Read-only postflight supplied by operator

The 2026-10-29 HeidiSQL screenshots showed:

| Table.column | Observed type | Nullable |
| --- | --- | --- |
| `user_bans.date` | `date` | YES |
| `user_bans.reason` | `varchar(2048)` | NO |
| `user_bans.reason_details` | `varchar(2048)` | YES |
| `user_bans.applied_by` | `int(11)` | YES |
| `user_warnings.date` | `date` | NO |
| `user_warnings.reason` | `varchar(1024)` | NO |

Indexes observed with `NON_UNIQUE=1`:

- `idx_user_bans_community_date(community_id,date)`
- `idx_user_warnings_community_user_date(community_id,user_id,date)`

The former `unique_ban` and `unique_warning` did not appear in the
filtered index result. No duplicate-warning check was performed against
individual records; do **not** infer deduplication, loss or corruption.

The postflight counted 67 bans, 347 warnings and 0 bans with a non-null
`reason_details`, as expected for legacy bans. A separate earlier
preflight screenshot displayed 317 warnings, but the operator reports
347 in other earlier captures. These snapshots lack a consistent time
boundary and are insufficient evidence of a migration-caused increase
or anomaly. **No issue is asserted on row-count difference alone.**

## Unverified release gates

- Full `SHOW CREATE TABLE` statements were truncated in the screenshots;
  exact PK, FK, referenced actions and index relationships have not been
  independently checked after DDL.
- The recoverability and timestamp of the production backup were not
  provided as evidence in this record.
- No live data hashes, transactional before/after diff or actual Discord
  moderation action tests were performed by the assistant.
- API #55 and Coddy #39/#40/#41 (integration #42) need merge/CI and separate
  deployment authorization. Production application compatibility is not yet
  established merely by successful Database postflight.

Keep sensitive moderation reasons, member IDs, credentials, raw backups and
SQL query output outside the public repository.
