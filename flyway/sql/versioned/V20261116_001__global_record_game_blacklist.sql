-- Coddy record games blacklist becomes a single platform-wide policy.
-- The existing per-guild blacklisted_games table is kept as immutable legacy data
-- for rollback/forensics; no guild-specific records are deleted or rewritten.
-- Legacy names from all guilds are intentionally consolidated into one policy.
-- Rollout: Database -> Coddy global reads/slash fallback -> API -> Front -> retire slash.
CREATE TABLE record_global_blacklisted_games (
    id INT(11) NOT NULL AUTO_INCREMENT,
    game_name VARCHAR(50) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_rgbg_game_name (game_name),
    CONSTRAINT ck_rgbg_name_nonempty CHECK (CHAR_LENGTH(TRIM(game_name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Preserve prior exclusions when the legacy per-guild table exists.
-- blacklisted_games is not part of the Flyway baseline, so fresh/disposable schemas
-- may have no legacy table. Existing deployments still import every distinct name.
-- Do not use INSERT IGNORE: a too-long legacy name must fail, not silently truncate.
SET @record_legacy_blacklist_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'blacklisted_games'
);
SET @record_legacy_blacklist_import = IF(
    @record_legacy_blacklist_exists = 1,
    'INSERT INTO record_global_blacklisted_games (game_name)
     SELECT DISTINCT TRIM(game_name)
     FROM blacklisted_games
     WHERE game_name IS NOT NULL
       AND CHAR_LENGTH(TRIM(game_name)) > 0
       AND TRIM(game_name) <> ''0''
     ON DUPLICATE KEY UPDATE record_global_blacklisted_games.game_name = record_global_blacklisted_games.game_name',
    'DO 0'
);
PREPARE record_legacy_blacklist_import_stmt FROM @record_legacy_blacklist_import;
EXECUTE record_legacy_blacklist_import_stmt;
DEALLOCATE PREPARE record_legacy_blacklist_import_stmt;

-- Persistent audit of global configuration changes; legacy imported rows do not
-- have identifiable actors, so migration itself does not fabricate events.
CREATE TABLE record_global_blacklist_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    entry_id INT(11) NULL,
    game_name VARCHAR(50) NOT NULL,
    action_type VARCHAR(8) NOT NULL,
    actor_user_id INT(11) NOT NULL,
    occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_rgba_time (occurred_at),
    KEY idx_rgba_actor_time (actor_user_id, occurred_at),
    CONSTRAINT fk_rgba_actor FOREIGN KEY (actor_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_rgba_action CHECK (action_type IN ('ADD','REMOVE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
