# Voice XP audit: bounded 72-hour retention

## Authority and compatibility

- **Database** owns schema and the additive `idx_voice_xp_audit_retention (created_at, id)` migration.
- **Coddy** continues inserting `voice_xp_audit_log` and updating `voice_xp_daily_metrics`. No Coddy rollout is needed.
- **API** runs the opt-in cleanup without exposing an endpoint or tenant-controlled operation.
- This affects **all Communities** only through deletion of expired diagnostics; no current account, XP grant, session, aggregate, or moderation audit is deleted.
- The `server_guild_id` and `discord_user_id` are Discord snowflakes, **not** internal IDs.
- API/Coddy N and N-1 remain compatible with the new index.

## Retention policy

- Expire detailed `voice_xp_audit_log` rows older than **72 hours** (measured against the database's `CURRENT_TIMESTAMP`, matching the column's default clock).
- Every **5 minutes**, delete up to **10 batches of 500 rows**, ordered by `created_at, id`.
- Each JDBC update commits separately; do **not** wrap the whole loop in one transaction.
- The cleanup is **disabled by default** with `VOICE_XP_AUDIT_RETENTION_ENABLED=false`; enable only after DB rollout and explicit production approval.
- The daily aggregate `voice_xp_daily_metrics`, accrued `user_level` XP and `voice_sessions` are never purged by this job.

## Production preflight — read only

Run under a constrained account against the **verified** target MariaDB:

```sql
SELECT DATABASE(), VERSION(), @@time_zone, @@system_time_zone, CURRENT_TIMESTAMP;
SHOW CREATE TABLE voice_xp_audit_log;
SHOW INDEX FROM voice_xp_audit_log;
SELECT table_name, engine, table_rows,
       ROUND(data_length / 1024 / 1024, 1) AS data_mib,
       ROUND(index_length / 1024 / 1024, 1) AS index_mib
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('voice_xp_audit_log','voice_xp_daily_metrics','voice_sessions','user_level');
SELECT COUNT(*) AS total_rows,
       SUM(created_at < CURRENT_TIMESTAMP - INTERVAL 72 HOUR) AS expired_rows,
       MIN(created_at) AS oldest_record,
       MAX(created_at) AS newest_record
FROM voice_xp_audit_log;
```

The count scans a large table; perform it **off peak**. Verify that all rows use a consistent database clock. Ensure backups and enough disk capacity for an online index build/rebuild. Confirm the named index does not already exist and no competing Database migration is in progress.

## Release order

1. Review the Database migration and CI against disposable MariaDB. Do not rewrite any already applied migration.
2. Apply `V20261111_001__index_voice_xp_audit_retention.sql` via the approved Database release process; record before/after index shape and migration checksum.
3. Verify `idx_voice_xp_audit_retention` exists and that an `EXPLAIN` of the bounded DELETE can use it. Do **not** run the DELETE as a preflight query.
4. Merge/deploy the API code with the retention flag **off**. Verify health and normal voice XP/daily metrics.
5. With separate approval, enable `VOICE_XP_AUDIT_RETENTION_ENABLED=true` in the API production environment and deploy/restart it through the approved flow.
6. Observe 5-minute purge batch counts, database CPU/locks, growth of `voice_xp_audit_log`, and Coddy XP award success. Disable the flag if contention or unexpected behavior appears.

## Physical disk recovery (separate maintenance)

InnoDB `DELETE` makes space reusable inside the table but usually **does not immediately shrink** the table's on-disk footprint. After the backlog is drained, recheck the size. Any `OPTIMIZE TABLE voice_xp_audit_log` or table rebuild requires a **separately approved maintenance window**, backup/restore plan, free disk, and lock/replication review. It is not part of the migration or automatic retention job.

## Safe rollback

- Disable the API retention flag to stop future deletes.
- The additive index can remain; code is backward compatible.
- Deleted diagnostics cannot be reconstructed except from backups, and **must not** be presented as XP ledger mutations.
- Do not run `TRUNCATE`, unrestricted `DELETE`, or `OPTIMIZE TABLE` as part of this rollout.
