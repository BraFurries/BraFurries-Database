-- TEST FIXTURE ONLY. Never move this file into flyway/sql/ or run it outside disposable validation.
CREATE TABLE `__brf_flyway_smoke_test` (
    `id` INT NOT NULL,
    `fixture_name` VARCHAR(64) NOT NULL,
    `applied_at` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`)
) ENGINE=InnoDB;

INSERT INTO `__brf_flyway_smoke_test` (`id`, `fixture_name`)
VALUES (1, 'phase_2_disposable_fixture');

-- Minimal canonical prerequisite for exercising later User-referencing migrations.
CREATE TABLE `users` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `display_name` VARCHAR(100) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- TEST FIXTURE ONLY: observed legacy XP shape before the guild-key repair and
-- daily-cap columns formalized by V20261004_001. The standalone UNIQUE(user_id)
-- intentionally reproduces the legacy multitenancy defect.
CREATE TABLE `user_level` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `server_guild_id` BIGINT(20) NOT NULL,
    `total_xp` BIGINT(20) NOT NULL DEFAULT 0,
    `current_level` INT(11) NOT NULL DEFAULT 0,
    `daily_recs_count` INT(11) NULL DEFAULT NULL,
    `weekly_bump_xp` INT(11) NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `user_id` (`user_id`),
    KEY `idx_fixture_user_level_user_guild` (`user_id`, `server_guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- TEST FIXTURE ONLY: minimal current-membership prerequisite.
CREATE TABLE `communities` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- TEST FIXTURE ONLY: minimal existing Community Team role prerequisite.
-- The production table was introduced by the approved manual DDL documented in Database PR #4.
CREATE TABLE `community_team_roles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `parent_role_id` INT(11) DEFAULT NULL,
    `name` VARCHAR(100) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_ctr_community_id_id` (`community_id`, `id`),
    KEY `idx_ctr_parent` (`community_id`, `parent_role_id`),
    CONSTRAINT `fk_fixture_ctr_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_fixture_ctr_parent_same_community`
        FOREIGN KEY (`community_id`, `parent_role_id`)
        REFERENCES `community_team_roles` (`community_id`, `id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_community_status` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `community_id` INT(11) NOT NULL,
    `member_since` DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_fixture_ucs_user` (`user_id`),
    KEY `idx_fixture_ucs_community` (`community_id`),
    CONSTRAINT `fk_fixture_ucs_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT `fk_fixture_ucs_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE NO ACTION ON DELETE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- TEST FIXTURE ONLY: legacy Portaria configuration before lifecycle state.
CREATE TABLE `portaria_base_config` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT(20) NOT NULL,
    `formulario_portaria_ativo` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_fixture_portaria_base_config_guild` (`server_guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- TEST FIXTURE ONLY: minimal legacy Portaria flow table used to distinguish
-- a configured Portaria from an incidental base-config row.
CREATE TABLE `form_flows` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT(20) NOT NULL,
    `type` VARCHAR(64) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_fixture_form_flows_guild_type` (`server_guild_id`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `users` (`id`, `display_name`) VALUES (77, 'Legacy Member');
INSERT INTO `communities` (`id`, `name`) VALUES (77, 'Legacy Community');
INSERT INTO `user_community_status` (`id`, `user_id`, `community_id`, `member_since`)
VALUES (77, 77, 77, '2026-01-01 00:00:00');
INSERT INTO `portaria_base_config` (`id`, `server_guild_id`, `formulario_portaria_ativo`)
VALUES
    (77, 7700, 0),
    (78, 7800, 1);
INSERT INTO `form_flows` (`id`, `server_guild_id`, `type`)
VALUES (78, 7800, 'portaria');

-- TEST FIXTURE ONLY: minimal existing moderation-action prerequisite.
CREATE TABLE `user_bans` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `community_id` INT(11) NOT NULL,
    `date` DATETIME NOT NULL,
    `reason` VARCHAR(255) DEFAULT NULL,
    `applied_by` INT(11) DEFAULT NULL,
    `revoked_at` DATETIME(6) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_fixture_user_bans_user` (`user_id`),
    KEY `idx_fixture_user_bans_community` (`community_id`),
    CONSTRAINT `fk_fixture_user_bans_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
    CONSTRAINT `fk_fixture_user_bans_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- TEST FIXTURE ONLY: minimal prerequisite for the monthly Bump reward ledger FK.
CREATE TABLE `community_discord` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `guild_id` BIGINT(20) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `discord_admin_id` BIGINT(20) DEFAULT NULL,
    `users_quantity` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `community_id` (`community_id`),
    UNIQUE KEY `name` (`name`),
    UNIQUE KEY `guild_id` (`guild_id`),
    CONSTRAINT `fk_fixture_community_discord_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- TEST FIXTURE ONLY: observed legacy VIP custom-role shape before
-- color2/role_id were formalized by the official VIP migration.
CREATE TABLE IF NOT EXISTS `user_custom_roles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `server_guild_id` BIGINT(20) NOT NULL,
    `color` VARCHAR(32) NULL DEFAULT NULL,
    `icon_id` BIGINT(20) NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_fixture_user_custom_roles_user_guild` (`user_id`, `server_guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- TEST FIXTURE ONLY: minimal legacy preconditions for the Bump migration.
-- These are not a canonical baseline and deliberately omit all Bump columns.
CREATE TABLE IF NOT EXISTS `config_server_settings` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_fixture_config_server_settings_guild` (`server_guild_id`)
) ENGINE=InnoDB;

-- TEST FIXTURE ONLY: currency columns model required legacy fields only.
CREATE TABLE IF NOT EXISTS `config_economy` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT NOT NULL,
    `currency_name` VARCHAR(16) NOT NULL,
    `currency_prefix` VARCHAR(16) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_fixture_config_economy_guild` (`server_guild_id`)
) ENGINE=InnoDB;


-- TEST FIXTURE ONLY: populated legacy Backup shape created historically by Coddy runtime DDL.
-- Intentionally omits backup_type, periodicity_frequency, newer indexes/FKs and
-- operation tables so V20261007_002 proves additive migration without data loss.
CREATE TABLE IF NOT EXISTS `backup_discord` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `guild_id` BIGINT NOT NULL,
    `original_name` VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_backup_discord_guild` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `backup_roles` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `backup_id` INT NOT NULL,
    `discord_id` BIGINT NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `color` BIGINT NOT NULL DEFAULT 0,
    `permissions` BIGINT NOT NULL DEFAULT 0,
    `position` INT NOT NULL DEFAULT 0,
    `hoist` TINYINT(1) NOT NULL DEFAULT 0,
    `mentionable` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `backup_channels` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `backup_id` INT NOT NULL,
    `discord_id` BIGINT NOT NULL,
    `parent_id` BIGINT NULL,
    `name` VARCHAR(255) NOT NULL,
    `type` INT NOT NULL,
    `position` INT NULL,
    `topic` TEXT NULL,
    `nsfw` TINYINT(1) NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `backup_overwrites` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `channel_id` INT NOT NULL,
    `role_name` VARCHAR(255) NOT NULL,
    `role_id` INT NOT NULL,
    `allow_bits` BIGINT NOT NULL DEFAULT 0,
    `deny_bits` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `backup_server_settings` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `guild_id` BIGINT NOT NULL,
    `max_normal_backups` INT NOT NULL DEFAULT 5,
    `max_periodic_backups` INT NOT NULL DEFAULT 1,
    `periodic_backups_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `periodicity_minutes` INT NOT NULL DEFAULT 10080,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_backup_server_settings_guild` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `backup_discord` (`id`, `guild_id`, `original_name`, `created_at`)
VALUES (9001, 99001, 'Legacy populated backup', '2026-09-01 01:02:03');

INSERT INTO `backup_roles`
    (`id`, `backup_id`, `discord_id`, `name`, `color`, `permissions`, `position`, `hoist`, `mentionable`)
VALUES
    (9100, 9001, 99001, '@everyone', 0, 1024, 0, 0, 0),
    (9101, 9001, 99101, 'Legacy Role', 16711680, 8, 5, 1, 0);

INSERT INTO `backup_channels`
    (`id`, `backup_id`, `discord_id`, `parent_id`, `name`, `type`, `position`, `topic`, `nsfw`)
VALUES
    (9201, 9001, 99201, NULL, 'legacy-channel', 0, 3, 'legacy topic', 0);

INSERT INTO `backup_overwrites`
    (`id`, `channel_id`, `role_name`, `role_id`, `allow_bits`, `deny_bits`)
VALUES
    (9300, 9201, '@everyone', 9100, 0, 1024),
    (9301, 9201, 'Legacy Role', 9101, 1024, 2048);

INSERT INTO `backup_server_settings`
    (`id`, `guild_id`, `max_normal_backups`, `max_periodic_backups`,
     `periodic_backups_enabled`, `periodicity_minutes`)
VALUES
    (9401, 99001, 7, 2, 1, 1440);
