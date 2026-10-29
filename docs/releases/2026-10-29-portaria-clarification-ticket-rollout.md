# Portaria — clarification tickets V1 rollout (planned; NOT deployed)

This document is an **operator checklist**, not evidence of production DDL.
The feature is Discord-only; the website configures ON/OFF and the category.
The reviewed Database migration is
`flyway/sql/versioned/V20261029_005__create_portaria_clarification_tickets.sql`.

## Ownership and dependency order

1. Review the **actual** existing production table structure, indexes and FKs
   before applying migration V20261029_005. The schema is owned by Database.
2. Take and verify a **recoverable backup** before manual DDL. Production Flyway
   adoption was deferred in the earlier moderation rollout; do not introduce
   a fictional `flyway_schema_history` or rerun migrations 002–004.
3. Apply exactly the reviewed V005 DDL manually **once** to the intended
   database. MariaDB DDL auto-commits; do not assume a transactional rollback.
4. Perform the read-only postflight checks below before deploying code.
5. After authorization, deploy API config (#58), Coddy (#43), then Front (#40).
6. Leave `clarification_tickets_enabled=0` in every guild until the full
   smoke checks are complete; enable only for a specific test Community.

Never deploy a Coddy build that reads the new configuration column before
the schema exists. Never merge/deploy or run DDL without the owner authorization.

## Read-only preflight (production, HeidiSQL)

```sql
SELECT DATABASE() AS current_schema, VERSION() AS mariadb_version;
SHOW CREATE TABLE portaria_base_config;
SHOW CREATE TABLE form_submissions;
SHOW CREATE TABLE community_discord;
SELECT COUNT(*) AS existing_submissions FROM form_submissions;
SELECT COUNT(*) AS existing_configs FROM portaria_base_config;
SELECT COUNT(*) AS existing_guild_links FROM community_discord;
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE()
   AND TABLE_NAME IN ('portaria_base_config','form_submissions','community_discord')
   AND COLUMN_NAME IN ('id','community_id','guild_id','server_guild_id',
                       'portaria_enabled','clarification_tickets_enabled',
                       'clarification_ticket_category_id')
 ORDER BY TABLE_NAME, ORDINAL_POSITION;
```

**Stop** if columns, types, indexes or FK targets differ from the reviewed
migration, especially if guild/submission cardinalities differ. Never guess
the right structure or modify existing records to make DDL fit.

## Postflight — read-only checks

```sql
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE()
   AND (
      TABLE_NAME = 'portaria_clarification_tickets'
      OR (TABLE_NAME='portaria_base_config'
          AND COLUMN_NAME IN ('clarification_tickets_enabled',
                              'clarification_ticket_category_id'))
   )
 ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS indexed_columns
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA = DATABASE()
   AND TABLE_NAME IN ('portaria_clarification_tickets','form_submissions',
                      'community_discord')
   AND INDEX_NAME IN ('uq_pct_community_submission','uq_pct_guild_channel',
                      'uq_form_submissions_id_guild',
                      'uq_community_discord_community_guild')
 GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE
 ORDER BY TABLE_NAME, INDEX_NAME;

SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME,
       COLUMN_NAME, REFERENCED_COLUMN_NAME
  FROM information_schema.KEY_COLUMN_USAGE
 WHERE TABLE_SCHEMA=DATABASE()
   AND TABLE_NAME='portaria_clarification_tickets'
   AND REFERENCED_TABLE_NAME IS NOT NULL
 ORDER BY CONSTRAINT_NAME, ORDINAL_POSITION;

SELECT
  (SELECT COUNT(*) FROM form_submissions) AS submissions,
  (SELECT COUNT(*) FROM portaria_base_config) AS configs,
  (SELECT COUNT(*) FROM community_discord) AS guild_links,
  (SELECT COUNT(*) FROM portaria_clarification_tickets) AS new_ticket_rows,
  (SELECT COUNT(*) FROM portaria_base_config
   WHERE clarification_tickets_enabled <> 0) AS enabled_configs;

SHOW CREATE TABLE portaria_clarification_tickets;
```

**Expected immediately after DDL:** `new_ticket_rows=0` and
`enabled_configs=0`; existing submission/config/guild-link row counts
unchanged, unless legitimate activity occurred after preflight. New indexes
and composite FKs must match the reviewed migration.

## Gated smoke test after code rollout

- With flag OFF: existing Portaria decisions and forms remain functional.
- Only an authorized Web manager can enable tickets and select a category.
- A Staff member requests clarification **in Discord**, not on the site.
- Confirm applicant, Staff and Coddy can access the channel, and an unrelated
  member cannot (also validate tenant/guild separation).
- Verify retry after a lost Discord response does not duplicate channels;
  verify recovery if the channel was manually deleted.
- Verify that a pending ticket blocks form approval/rejection even under
  concurrent actions, and that closing the ticket never decides the form.
- Confirm persistent close button works after bot restart and that the
  original form can be decided after a successful closure.
- Disable feature without deleting any existing ticket history.

Do not close related issues until these acceptance criteria are evidenced.
If a production schema migration fails halfway, stop and reconcile actual DDL
manually from the backup and real schema; do not blindly rerun the entire SQL.
