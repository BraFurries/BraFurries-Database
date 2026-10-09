-- Formalizes the existing Bump configuration shape. Production preflight must
-- verify existing column definitions; IF NOT EXISTS does not repair divergence.
CREATE TABLE IF NOT EXISTS `allowed_feature_channels` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT(20) NOT NULL,
    `feature_key` VARCHAR(100) NOT NULL,
    `channel_id` BIGINT(20) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_allowed_feature_channels` (`server_guild_id`, `feature_key`, `channel_id`),
    KEY `idx_allowed_feature_channels_lookup` (`server_guild_id`, `feature_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `config_server_settings`
    ADD COLUMN IF NOT EXISTS `bump_warn_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `bump_warn_disboard_channel_id` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_warn_target_channel_id` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_warn_messages` TEXT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_warn_next_at` DATETIME NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_warn_last_bump_at` DATETIME NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_reward_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `bump_reward_temp_role_id` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_reward_role_minutes` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `bump_reward_coins` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `bump_reward_message` TEXT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_monthly_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `bump_monthly_disboard_channel_id` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_monthly_reward_role_id` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_monthly_reward_days_1` INT(11) NOT NULL DEFAULT 21,
    ADD COLUMN IF NOT EXISTS `bump_monthly_reward_days_2` INT(11) NOT NULL DEFAULT 14,
    ADD COLUMN IF NOT EXISTS `bump_monthly_reward_days_3` INT(11) NOT NULL DEFAULT 7,
    ADD COLUMN IF NOT EXISTS `bump_monthly_reward_coins_1` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `bump_monthly_reward_coins_2` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `bump_monthly_reward_coins_3` INT(11) NOT NULL DEFAULT 0;

ALTER TABLE `config_economy`
    ADD COLUMN IF NOT EXISTS `bump_points` INT(11) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `bump_reward_enabled` TINYINT(1) NOT NULL DEFAULT 0;
