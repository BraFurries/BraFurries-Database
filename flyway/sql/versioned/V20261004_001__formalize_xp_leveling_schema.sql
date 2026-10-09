-- Formalizes the active XP/leveling schema currently maintained by legacy
-- BraFurries-Discord runtime DDL, and expands guild-scoped XP controls.
--
-- Compatibility:
-- - additive for config/telemetry objects;
-- - preserves all existing XP totals and levels;
-- - does not redistribute historical XP across guilds;
-- - replaces the legacy UNIQUE(user_id) invariant with the canonical
--   UNIQUE(user_id, server_guild_id) key required by per-guild XP.
--
-- Legacy columns such as pivot_level/phase2_c are intentionally NOT dropped
-- here. Runtime-DDL retirement is a later contract step.

CREATE TABLE IF NOT EXISTS `config_levels` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT(20) NOT NULL,
    `clear_on_exit` TINYINT(1) NOT NULL DEFAULT 0,
    `levelup_warning` TINYINT(1) NOT NULL DEFAULT 0,
    `levelup_warning_channel` BIGINT(20) NULL DEFAULT NULL,
    `level_up_message` TEXT NULL DEFAULT NULL,
    `multiplier` DECIMAL(20,3) NULL DEFAULT NULL,
    `phase1_k` DECIMAL(20,3) NOT NULL DEFAULT 45.000,
    `phase1_p` DECIMAL(20,3) NOT NULL DEFAULT 2.000,
    `phase1_b` DECIMAL(20,3) NOT NULL DEFAULT 0.000,
    `daily_combo` INT(11) NULL DEFAULT NULL,
    `combo_multiplier` DECIMAL(20,3) NULL DEFAULT NULL,
    `xp_base_per_min` INT(11) NOT NULL DEFAULT 2,
    `voice_social_bonus_pct` DECIMAL(8,4) NOT NULL DEFAULT 0.0000,
    `voice_social_bonus_min_humans` INT(11) NOT NULL DEFAULT 2,
    `voice_diminishing_window1_minutes` INT(11) NOT NULL DEFAULT 60,
    `voice_diminishing_window2_minutes` INT(11) NOT NULL DEFAULT 120,
    `voice_diminishing_factor2` DECIMAL(8,4) NOT NULL DEFAULT 0.6000,
    `voice_diminishing_factor3` DECIMAL(8,4) NOT NULL DEFAULT 0.3000,
    `voice_daily_cap_xp` INT(11) NOT NULL DEFAULT 600,
    `text_daily_cap_xp` INT(11) NOT NULL DEFAULT 300,
    `global_daily_cap_xp` INT(11) NOT NULL DEFAULT 900,
    `text_xp_enabled` TINYINT(1) NULL DEFAULT NULL,
    `voice_xp_enabled` TINYINT(1) NULL DEFAULT NULL,
    `text_xp_base_min` INT(11) NULL DEFAULT NULL,
    `text_xp_base_max` INT(11) NULL DEFAULT NULL,
    `text_xp_cooldown_min_seconds` INT(11) NULL DEFAULT NULL,
    `text_xp_cooldown_max_seconds` INT(11) NULL DEFAULT NULL,
    `level_reconcile_required` TINYINT(1) NOT NULL DEFAULT 0,
    `level_reconcile_requested_at` DATETIME(6) NULL DEFAULT NULL,
    `level_reconciled_at` DATETIME(6) NULL DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Repair older config_levels variants without removing legacy columns.
ALTER TABLE `config_levels`
    ADD COLUMN IF NOT EXISTS `clear_on_exit` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `levelup_warning` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `levelup_warning_channel` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `level_up_message` TEXT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `multiplier` DECIMAL(20,3) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `phase1_k` DECIMAL(20,3) NOT NULL DEFAULT 45.000,
    ADD COLUMN IF NOT EXISTS `phase1_p` DECIMAL(20,3) NOT NULL DEFAULT 2.000,
    ADD COLUMN IF NOT EXISTS `phase1_b` DECIMAL(20,3) NOT NULL DEFAULT 0.000,
    ADD COLUMN IF NOT EXISTS `daily_combo` INT(11) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `combo_multiplier` DECIMAL(20,3) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `xp_base_per_min` INT(11) NOT NULL DEFAULT 2,
    ADD COLUMN IF NOT EXISTS `voice_social_bonus_pct` DECIMAL(8,4) NOT NULL DEFAULT 0.0000,
    ADD COLUMN IF NOT EXISTS `voice_social_bonus_min_humans` INT(11) NOT NULL DEFAULT 2,
    ADD COLUMN IF NOT EXISTS `voice_diminishing_window1_minutes` INT(11) NOT NULL DEFAULT 60,
    ADD COLUMN IF NOT EXISTS `voice_diminishing_window2_minutes` INT(11) NOT NULL DEFAULT 120,
    ADD COLUMN IF NOT EXISTS `voice_diminishing_factor2` DECIMAL(8,4) NOT NULL DEFAULT 0.6000,
    ADD COLUMN IF NOT EXISTS `voice_diminishing_factor3` DECIMAL(8,4) NOT NULL DEFAULT 0.3000,
    ADD COLUMN IF NOT EXISTS `voice_daily_cap_xp` INT(11) NOT NULL DEFAULT 600,
    ADD COLUMN IF NOT EXISTS `text_daily_cap_xp` INT(11) NOT NULL DEFAULT 300,
    ADD COLUMN IF NOT EXISTS `global_daily_cap_xp` INT(11) NOT NULL DEFAULT 900,
    ADD COLUMN IF NOT EXISTS `text_xp_enabled` TINYINT(1) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `voice_xp_enabled` TINYINT(1) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `text_xp_base_min` INT(11) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `text_xp_base_max` INT(11) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `text_xp_cooldown_min_seconds` INT(11) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `text_xp_cooldown_max_seconds` INT(11) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `level_reconcile_required` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `level_reconcile_requested_at` DATETIME(6) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `level_reconciled_at` DATETIME(6) NULL DEFAULT NULL;

-- Preserve current behavior for every existing guild. Voice rows with a zero
-- base rate remain effectively disabled when the explicit flag is introduced.
UPDATE `config_levels`
SET
    `text_xp_enabled` = COALESCE(`text_xp_enabled`, 1),
    `voice_xp_enabled` = COALESCE(
        `voice_xp_enabled`,
        CASE WHEN COALESCE(`xp_base_per_min`, 0) > 0 THEN 1 ELSE 0 END
    ),
    `text_xp_base_min` = COALESCE(`text_xp_base_min`, 8),
    `text_xp_base_max` = COALESCE(`text_xp_base_max`, 16),
    `text_xp_cooldown_min_seconds` = COALESCE(`text_xp_cooldown_min_seconds`, 30),
    `text_xp_cooldown_max_seconds` = COALESCE(`text_xp_cooldown_max_seconds`, 60);

ALTER TABLE `config_levels`
    MODIFY COLUMN `text_xp_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    MODIFY COLUMN `voice_xp_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    MODIFY COLUMN `text_xp_base_min` INT(11) NOT NULL DEFAULT 8,
    MODIFY COLUMN `text_xp_base_max` INT(11) NOT NULL DEFAULT 16,
    MODIFY COLUMN `text_xp_cooldown_min_seconds` INT(11) NOT NULL DEFAULT 30,
    MODIFY COLUMN `text_xp_cooldown_max_seconds` INT(11) NOT NULL DEFAULT 60;

-- Ensure one configuration row per Discord guild without assuming a legacy
-- index name.
SET @xp_has_config_guild_unique := (
    SELECT COUNT(*)
    FROM (
        SELECT `INDEX_NAME`
        FROM `information_schema`.`STATISTICS`
        WHERE `TABLE_SCHEMA` = DATABASE()
          AND `TABLE_NAME` = 'config_levels'
          AND `NON_UNIQUE` = 0
          AND `INDEX_NAME` <> 'PRIMARY'
        GROUP BY `INDEX_NAME`
        HAVING GROUP_CONCAT(`COLUMN_NAME` ORDER BY `SEQ_IN_INDEX`) = 'server_guild_id'
    ) AS existing_unique_indexes
);
SET @xp_config_unique_sql := IF(
    @xp_has_config_guild_unique = 0,
    'ALTER TABLE `config_levels` ADD UNIQUE KEY `uk_config_levels_server_guild` (`server_guild_id`)',
    'SELECT 1'
);
PREPARE xp_config_unique_stmt FROM @xp_config_unique_sql;
EXECUTE xp_config_unique_stmt;
DEALLOCATE PREPARE xp_config_unique_stmt;

-- Runtime cap accounting columns. user_level itself is legacy/baseline
-- structure and is intentionally not recreated here.
ALTER TABLE `user_level`
    ADD COLUMN IF NOT EXISTS `xp_awarded_voice_today` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `xp_awarded_voice_day` DATE NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `xp_awarded_text_today` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `xp_awarded_text_day` DATE NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `xp_awarded_today` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `xp_awarded_day` DATE NULL DEFAULT NULL;

-- The logical XP identity is (user_id, server_guild_id). Add the canonical
-- composite unique key first, then retire only a unique index whose complete
-- column list is exactly user_id. No XP row is copied, merged, or redistributed.
SET @xp_has_user_guild_unique := (
    SELECT COUNT(*)
    FROM (
        SELECT `INDEX_NAME`
        FROM `information_schema`.`STATISTICS`
        WHERE `TABLE_SCHEMA` = DATABASE()
          AND `TABLE_NAME` = 'user_level'
          AND `NON_UNIQUE` = 0
          AND `INDEX_NAME` <> 'PRIMARY'
        GROUP BY `INDEX_NAME`
        HAVING GROUP_CONCAT(`COLUMN_NAME` ORDER BY `SEQ_IN_INDEX`) = 'user_id,server_guild_id'
    ) AS existing_unique_indexes
);
SET @xp_user_guild_unique_sql := IF(
    @xp_has_user_guild_unique = 0,
    'ALTER TABLE `user_level` ADD UNIQUE KEY `uk_user_level_user_guild` (`user_id`, `server_guild_id`)',
    'SELECT 1'
);
PREPARE xp_user_guild_unique_stmt FROM @xp_user_guild_unique_sql;
EXECUTE xp_user_guild_unique_stmt;
DEALLOCATE PREPARE xp_user_guild_unique_stmt;

SET @xp_legacy_user_unique_index := (
    SELECT `INDEX_NAME`
    FROM `information_schema`.`STATISTICS`
    WHERE `TABLE_SCHEMA` = DATABASE()
      AND `TABLE_NAME` = 'user_level'
      AND `NON_UNIQUE` = 0
      AND `INDEX_NAME` <> 'PRIMARY'
    GROUP BY `INDEX_NAME`
    HAVING GROUP_CONCAT(`COLUMN_NAME` ORDER BY `SEQ_IN_INDEX`) = 'user_id'
    ORDER BY `INDEX_NAME`
    LIMIT 1
);
SET @xp_drop_legacy_user_unique_sql := IF(
    @xp_legacy_user_unique_index IS NULL,
    'SELECT 1',
    CONCAT(
        'ALTER TABLE `user_level` DROP INDEX `',
        REPLACE(@xp_legacy_user_unique_index, '`', '``'),
        '`'
    )
);
PREPARE xp_drop_legacy_user_unique_stmt FROM @xp_drop_legacy_user_unique_sql;
EXECUTE xp_drop_legacy_user_unique_stmt;
DEALLOCATE PREPARE xp_drop_legacy_user_unique_stmt;

-- Formalize persistent voice-session state. Preserve the legacy table name if
-- it is still present and the canonical table has not yet been created.
SET @xp_has_voice_sessions := (
    SELECT COUNT(*)
    FROM `information_schema`.`TABLES`
    WHERE `TABLE_SCHEMA` = DATABASE()
      AND `TABLE_NAME` = 'voice_sessions'
);
SET @xp_has_legacy_voice_sessions := (
    SELECT COUNT(*)
    FROM `information_schema`.`TABLES`
    WHERE `TABLE_SCHEMA` = DATABASE()
      AND `TABLE_NAME` = 'voice_xp_sessions'
);
SET @xp_rename_voice_sessions_sql := IF(
    @xp_has_voice_sessions = 0 AND @xp_has_legacy_voice_sessions = 1,
    'RENAME TABLE `voice_xp_sessions` TO `voice_sessions`',
    'SELECT 1'
);
PREPARE xp_rename_voice_sessions_stmt FROM @xp_rename_voice_sessions_sql;
EXECUTE xp_rename_voice_sessions_stmt;
DEALLOCATE PREPARE xp_rename_voice_sessions_stmt;

CREATE TABLE IF NOT EXISTS `voice_sessions` (
    `server_guild_id` BIGINT(20) NOT NULL,
    `discord_user_id` BIGINT(20) NOT NULL,
    `voice_channel_id` BIGINT(20) NOT NULL,
    `started_at` DATETIME NOT NULL,
    `last_tick_at` DATETIME NOT NULL,
    `is_eligible` TINYINT(1) NOT NULL DEFAULT 0,
    `is_self_muted` TINYINT(1) NOT NULL DEFAULT 0,
    `is_self_deafened` TINYINT(1) NOT NULL DEFAULT 0,
    `is_server_muted` TINYINT(1) NOT NULL DEFAULT 0,
    `is_server_deafened` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`server_guild_id`, `discord_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `voice_xp_audit_log` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT(20) NOT NULL,
    `discord_user_id` BIGINT(20) NOT NULL,
    `voice_channel_id` BIGINT(20) NULL DEFAULT NULL,
    `event_type` VARCHAR(64) NOT NULL,
    `xp_amount` INT(11) NOT NULL DEFAULT 0,
    `eligible_seconds` INT(11) NOT NULL DEFAULT 0,
    `ineligible_seconds` INT(11) NOT NULL DEFAULT 0,
    `meta_json` JSON NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_voice_xp_audit_guild_day` (`server_guild_id`, `created_at`),
    KEY `idx_voice_xp_audit_user_day` (`server_guild_id`, `discord_user_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `voice_xp_daily_metrics` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `metric_day` DATE NOT NULL,
    `server_guild_id` BIGINT(20) NOT NULL,
    `modality` VARCHAR(32) NOT NULL,
    `voice_channel_id` BIGINT(20) NULL DEFAULT NULL,
    `total_xp` BIGINT(20) NOT NULL DEFAULT 0,
    `grants_count` BIGINT(20) NOT NULL DEFAULT 0,
    `blocks_count` BIGINT(20) NOT NULL DEFAULT 0,
    `eligible_seconds` BIGINT(20) NOT NULL DEFAULT 0,
    `ineligible_seconds` BIGINT(20) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_voice_xp_daily_metrics`
        (`metric_day`, `server_guild_id`, `modality`, `voice_channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `config_levels`
    ADD CONSTRAINT `ck_config_levels_text_xp_enabled`
        CHECK (`text_xp_enabled` IN (0, 1)),
    ADD CONSTRAINT `ck_config_levels_voice_xp_enabled`
        CHECK (`voice_xp_enabled` IN (0, 1)),
    ADD CONSTRAINT `ck_config_levels_level_reconcile_required`
        CHECK (`level_reconcile_required` IN (0, 1)),
    ADD CONSTRAINT `ck_config_levels_text_xp_range`
        CHECK (
            `text_xp_base_min` >= 0
            AND `text_xp_base_max` >= `text_xp_base_min`
        ),
    ADD CONSTRAINT `ck_config_levels_text_cooldown_range`
        CHECK (
            `text_xp_cooldown_min_seconds` >= 0
            AND `text_xp_cooldown_max_seconds` >= `text_xp_cooldown_min_seconds`
        );
