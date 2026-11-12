-- Canonical administration analytics. Database owns all DDL.
-- Historical periods preceding instrumented collection are UNKNOWN, never zero.
-- Command events are recorded only on successful Discord command completion
-- with Discord-generated event IDs for at-least-once safe idempotency.
CREATE TABLE stats_coddy_command_executions (
    event_id BIGINT UNSIGNED NOT NULL,
    guild_id BIGINT NULL,
    command_name VARCHAR(128) NOT NULL,
    command_kind VARCHAR(16) NOT NULL,
    completed_at DATETIME(6) NOT NULL,
    PRIMARY KEY (event_id),
    KEY idx_scce_time_command (completed_at, command_name),
    KEY idx_scce_guild_time (guild_id, completed_at),
    CONSTRAINT ck_scce_kind CHECK (command_kind IN ('SLASH','PREFIX')),
    CONSTRAINT ck_scce_name CHECK (CHAR_LENGTH(TRIM(command_name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Each row is an actual observation, not a backfilled estimate.
-- BraFurries is the configured official Community, not a case-insensitive name.
-- brafurries_members is NULL if its guild lacks a healthy full reconciliation;
-- reach_unique_members is NULL if no active guild has a healthy reconciliation.
-- Both counts reflect DISTINCT platform identities, not verified unique humans.
CREATE TABLE stats_admin_daily_snapshots (
    community_id INT(11) NOT NULL,
    metric_date DATE NOT NULL,
    brafurries_members BIGINT UNSIGNED NULL,
    brafurries_reconciled TINYINT(1) NOT NULL DEFAULT 0,
    reach_unique_members BIGINT UNSIGNED NULL,
    reach_reconciled_guilds BIGINT UNSIGNED NOT NULL,
    reach_active_guilds BIGINT UNSIGNED NOT NULL,
    sampled_at DATETIME(6) NOT NULL,
    PRIMARY KEY (community_id, metric_date),
    KEY idx_sads_metric_date (metric_date),
    CONSTRAINT fk_sads_community FOREIGN KEY (community_id)
        REFERENCES communities(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_sads_flags CHECK (brafurries_reconciled IN (0,1)),
    CONSTRAINT ck_sads_brafurries_coverage CHECK (
        (brafurries_reconciled=1 AND brafurries_members IS NOT NULL)
        OR (brafurries_reconciled=0 AND brafurries_members IS NULL)
    ),
    CONSTRAINT ck_sads_reach_coverage CHECK (
        (reach_reconciled_guilds=0 AND reach_unique_members IS NULL)
        OR (reach_reconciled_guilds>0 AND reach_unique_members IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
