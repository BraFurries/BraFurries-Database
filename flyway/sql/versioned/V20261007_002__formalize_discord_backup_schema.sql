-- Formalize Discord structural backups and backup restore operations.
-- Database becomes the only schema authority for Backup. Existing runtime-created
-- tables/data are preserved; incompatible legacy data fails closed instead of
-- being deleted or silently rewritten.

CREATE TABLE IF NOT EXISTS `backup_discord` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `guild_id` BIGINT NOT NULL,
    `original_name` VARCHAR(255) NOT NULL,
    `backup_type` VARCHAR(20) NOT NULL DEFAULT 'normal',
    `created_by_discord_user_id` BIGINT NULL DEFAULT NULL,
    `idempotency_key` VARCHAR(96) NULL DEFAULT NULL,
    `creation_audited_at` DATETIME(6) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_backup_discord_guild` (`guild_id`),
    KEY `idx_backup_discord_guild_type` (`guild_id`, `backup_type`, `id`),
    UNIQUE KEY `uq_backup_discord_guild_idempotency` (`guild_id`, `idempotency_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `backup_discord`
    ADD COLUMN IF NOT EXISTS `backup_type` VARCHAR(20) NOT NULL DEFAULT 'normal' AFTER `original_name`,
    ADD COLUMN IF NOT EXISTS `created_by_discord_user_id` BIGINT NULL DEFAULT NULL AFTER `backup_type`,
    ADD COLUMN IF NOT EXISTS `idempotency_key` VARCHAR(96) NULL DEFAULT NULL AFTER `created_by_discord_user_id`,
    ADD COLUMN IF NOT EXISTS `creation_audited_at` DATETIME(6) NULL DEFAULT NULL AFTER `idempotency_key`,
    ADD INDEX IF NOT EXISTS `idx_backup_discord_guild` (`guild_id`),
    ADD INDEX IF NOT EXISTS `idx_backup_discord_guild_type` (`guild_id`, `backup_type`, `id`),
    ADD UNIQUE INDEX IF NOT EXISTS `uq_backup_discord_guild_idempotency` (`guild_id`, `idempotency_key`);

UPDATE `backup_discord`
SET `backup_type` = 'normal'
WHERE `backup_type` IS NULL
   OR LOWER(`backup_type`) NOT IN ('normal', 'periodic');

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
    PRIMARY KEY (`id`),
    KEY `idx_backup_roles_backup` (`backup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `backup_roles`
    ADD INDEX IF NOT EXISTS `idx_backup_roles_backup` (`backup_id`);

CREATE TABLE IF NOT EXISTS `backup_channels` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `backup_id` INT NOT NULL,
    `discord_id` BIGINT NOT NULL,
    `parent_id` BIGINT NULL DEFAULT NULL,
    `name` VARCHAR(255) NOT NULL,
    `type` INT NOT NULL,
    `position` INT NULL DEFAULT NULL,
    `topic` TEXT NULL,
    `nsfw` TINYINT(1) NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_backup_channels_backup` (`backup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `backup_channels`
    ADD INDEX IF NOT EXISTS `idx_backup_channels_backup` (`backup_id`);

CREATE TABLE IF NOT EXISTS `backup_overwrites` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `channel_id` INT NOT NULL,
    `role_name` VARCHAR(255) NOT NULL,
    `role_id` INT NOT NULL,
    `allow_bits` BIGINT NOT NULL DEFAULT 0,
    `deny_bits` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_backup_overwrites_channel` (`channel_id`),
    KEY `idx_backup_overwrites_role` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `backup_overwrites`
    ADD INDEX IF NOT EXISTS `idx_backup_overwrites_channel` (`channel_id`),
    ADD INDEX IF NOT EXISTS `idx_backup_overwrites_role` (`role_id`);

CREATE TABLE IF NOT EXISTS `backup_server_settings` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `guild_id` BIGINT NOT NULL,
    `max_normal_backups` INT NOT NULL DEFAULT 5,
    `max_periodic_backups` INT NOT NULL DEFAULT 1,
    `periodic_backups_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `periodicity_minutes` INT NOT NULL DEFAULT 10080,
    `periodicity_frequency` VARCHAR(10) NOT NULL DEFAULT 'weekly',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_backup_server_settings_guild` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `backup_server_settings`
    ADD COLUMN IF NOT EXISTS `periodicity_minutes` INT NOT NULL DEFAULT 10080 AFTER `periodic_backups_enabled`,
    ADD COLUMN IF NOT EXISTS `periodicity_frequency` VARCHAR(10) NULL DEFAULT NULL AFTER `periodicity_minutes`;

UPDATE `backup_server_settings`
SET `periodicity_frequency` = CASE
    WHEN `periodicity_frequency` IS NULL
      OR LOWER(`periodicity_frequency`) NOT IN ('daily', 'weekly', 'monthly')
    THEN CASE
        WHEN `periodicity_minutes` <= 1440 THEN 'daily'
        WHEN `periodicity_minutes` >= 43200 THEN 'monthly'
        ELSE 'weekly'
    END
    ELSE LOWER(`periodicity_frequency`)
END;

ALTER TABLE `backup_server_settings`
    MODIFY COLUMN `periodicity_frequency` VARCHAR(10) NOT NULL DEFAULT 'weekly',
    ADD UNIQUE INDEX IF NOT EXISTS `uq_backup_server_settings_guild` (`guild_id`);

-- Canonicalize foreign keys. Existing correctly-cascading constraints are kept.
-- If legacy rows are orphaned, adding the FK fails instead of deleting data.
SET @backup_roles_fk_ok = (
    SELECT COUNT(*)
    FROM information_schema.KEY_COLUMN_USAGE k
    JOIN information_schema.REFERENTIAL_CONSTRAINTS r
      ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
     AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
     AND r.TABLE_NAME = k.TABLE_NAME
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_roles'
      AND k.COLUMN_NAME = 'backup_id'
      AND k.REFERENCED_TABLE_NAME = 'backup_discord'
      AND k.REFERENCED_COLUMN_NAME = 'id'
      AND r.DELETE_RULE = 'CASCADE'
);
SET @backup_roles_fk_drop = (
    SELECT GROUP_CONCAT(CONCAT('DROP FOREIGN KEY `', k.CONSTRAINT_NAME, '`') SEPARATOR ', ')
    FROM information_schema.KEY_COLUMN_USAGE k
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_roles'
      AND k.COLUMN_NAME = 'backup_id'
      AND k.REFERENCED_TABLE_NAME IS NOT NULL
);
SET @backup_roles_fk_sql = IF(
    @backup_roles_fk_ok > 0,
    'SELECT 1',
    CONCAT(
        'ALTER TABLE `backup_roles` ',
        IF(@backup_roles_fk_drop IS NULL, '', CONCAT(@backup_roles_fk_drop, ', ')),
        'ADD CONSTRAINT `fk_backup_roles_backup` FOREIGN KEY (`backup_id`) REFERENCES `backup_discord`(`id`) ON DELETE CASCADE'
    )
);
PREPARE backup_roles_fk_stmt FROM @backup_roles_fk_sql;
EXECUTE backup_roles_fk_stmt;
DEALLOCATE PREPARE backup_roles_fk_stmt;

SET @backup_channels_fk_ok = (
    SELECT COUNT(*)
    FROM information_schema.KEY_COLUMN_USAGE k
    JOIN information_schema.REFERENTIAL_CONSTRAINTS r
      ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
     AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
     AND r.TABLE_NAME = k.TABLE_NAME
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_channels'
      AND k.COLUMN_NAME = 'backup_id'
      AND k.REFERENCED_TABLE_NAME = 'backup_discord'
      AND k.REFERENCED_COLUMN_NAME = 'id'
      AND r.DELETE_RULE = 'CASCADE'
);
SET @backup_channels_fk_drop = (
    SELECT GROUP_CONCAT(CONCAT('DROP FOREIGN KEY `', k.CONSTRAINT_NAME, '`') SEPARATOR ', ')
    FROM information_schema.KEY_COLUMN_USAGE k
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_channels'
      AND k.COLUMN_NAME = 'backup_id'
      AND k.REFERENCED_TABLE_NAME IS NOT NULL
);
SET @backup_channels_fk_sql = IF(
    @backup_channels_fk_ok > 0,
    'SELECT 1',
    CONCAT(
        'ALTER TABLE `backup_channels` ',
        IF(@backup_channels_fk_drop IS NULL, '', CONCAT(@backup_channels_fk_drop, ', ')),
        'ADD CONSTRAINT `fk_backup_channels_backup` FOREIGN KEY (`backup_id`) REFERENCES `backup_discord`(`id`) ON DELETE CASCADE'
    )
);
PREPARE backup_channels_fk_stmt FROM @backup_channels_fk_sql;
EXECUTE backup_channels_fk_stmt;
DEALLOCATE PREPARE backup_channels_fk_stmt;

SET @backup_overwrites_channel_fk_ok = (
    SELECT COUNT(*)
    FROM information_schema.KEY_COLUMN_USAGE k
    JOIN information_schema.REFERENTIAL_CONSTRAINTS r
      ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
     AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
     AND r.TABLE_NAME = k.TABLE_NAME
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_overwrites'
      AND k.COLUMN_NAME = 'channel_id'
      AND k.REFERENCED_TABLE_NAME = 'backup_channels'
      AND k.REFERENCED_COLUMN_NAME = 'id'
      AND r.DELETE_RULE = 'CASCADE'
);
SET @backup_overwrites_channel_fk_drop = (
    SELECT GROUP_CONCAT(CONCAT('DROP FOREIGN KEY `', k.CONSTRAINT_NAME, '`') SEPARATOR ', ')
    FROM information_schema.KEY_COLUMN_USAGE k
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_overwrites'
      AND k.COLUMN_NAME = 'channel_id'
      AND k.REFERENCED_TABLE_NAME IS NOT NULL
);
SET @backup_overwrites_channel_fk_sql = IF(
    @backup_overwrites_channel_fk_ok > 0,
    'SELECT 1',
    CONCAT(
        'ALTER TABLE `backup_overwrites` ',
        IF(@backup_overwrites_channel_fk_drop IS NULL, '', CONCAT(@backup_overwrites_channel_fk_drop, ', ')),
        'ADD CONSTRAINT `fk_backup_overwrites_channel` FOREIGN KEY (`channel_id`) REFERENCES `backup_channels`(`id`) ON DELETE CASCADE'
    )
);
PREPARE backup_overwrites_channel_fk_stmt FROM @backup_overwrites_channel_fk_sql;
EXECUTE backup_overwrites_channel_fk_stmt;
DEALLOCATE PREPARE backup_overwrites_channel_fk_stmt;

SET @backup_overwrites_role_fk_ok = (
    SELECT COUNT(*)
    FROM information_schema.KEY_COLUMN_USAGE k
    JOIN information_schema.REFERENTIAL_CONSTRAINTS r
      ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
     AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
     AND r.TABLE_NAME = k.TABLE_NAME
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_overwrites'
      AND k.COLUMN_NAME = 'role_id'
      AND k.REFERENCED_TABLE_NAME = 'backup_roles'
      AND k.REFERENCED_COLUMN_NAME = 'id'
      AND r.DELETE_RULE = 'CASCADE'
);
SET @backup_overwrites_role_fk_drop = (
    SELECT GROUP_CONCAT(CONCAT('DROP FOREIGN KEY `', k.CONSTRAINT_NAME, '`') SEPARATOR ', ')
    FROM information_schema.KEY_COLUMN_USAGE k
    WHERE k.TABLE_SCHEMA = DATABASE()
      AND k.TABLE_NAME = 'backup_overwrites'
      AND k.COLUMN_NAME = 'role_id'
      AND k.REFERENCED_TABLE_NAME IS NOT NULL
);
SET @backup_overwrites_role_fk_sql = IF(
    @backup_overwrites_role_fk_ok > 0,
    'SELECT 1',
    CONCAT(
        'ALTER TABLE `backup_overwrites` ',
        IF(@backup_overwrites_role_fk_drop IS NULL, '', CONCAT(@backup_overwrites_role_fk_drop, ', ')),
        'ADD CONSTRAINT `fk_backup_overwrites_role` FOREIGN KEY (`role_id`) REFERENCES `backup_roles`(`id`) ON DELETE CASCADE'
    )
);
PREPARE backup_overwrites_role_fk_stmt FROM @backup_overwrites_role_fk_sql;
EXECUTE backup_overwrites_role_fk_stmt;
DEALLOCATE PREPARE backup_overwrites_role_fk_stmt;

-- Durable restore state. backup_id is intentionally logical (no FK): retention
-- may prune an old snapshot after a completed restore while history remains.
CREATE TABLE IF NOT EXISTS `backup_restore_operations` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `guild_id` BIGINT NOT NULL,
    `backup_id` INT NOT NULL,
    `operation_key` VARCHAR(96) NOT NULL,
    `scope` VARCHAR(20) NOT NULL,
    `actor_discord_user_id` BIGINT NOT NULL,
    `actor_user_id` INT NULL DEFAULT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    `decision_json` LONGTEXT NULL,
    `result_json` LONGTEXT NULL,
    `error_code` VARCHAR(96) NULL DEFAULT NULL,
    `requested_audited_at` DATETIME(6) NULL DEFAULT NULL,
    `completion_audited_at` DATETIME(6) NULL DEFAULT NULL,
    `started_at` DATETIME(6) NULL DEFAULT NULL,
    `finished_at` DATETIME(6) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_backup_restore_guild_operation_key` (`guild_id`, `operation_key`),
    KEY `idx_backup_restore_guild_status` (`guild_id`, `status`, `id`),
    KEY `idx_backup_restore_backup` (`guild_id`, `backup_id`),
    CONSTRAINT `fk_backup_restore_actor`
        FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT `ck_backup_restore_scope`
        CHECK (`scope` IN ('full', 'roles', 'channels', 'permissions')),
    CONSTRAINT `ck_backup_restore_status`
        CHECK (`status` IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'PARTIAL', 'FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `backup_guild_locks` (
    `guild_id` BIGINT NOT NULL,
    `lock_token` VARCHAR(96) NOT NULL,
    `operation_type` VARCHAR(32) NOT NULL,
    `operation_id` BIGINT NULL DEFAULT NULL,
    `expires_at` DATETIME(6) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`guild_id`),
    KEY `idx_backup_guild_locks_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
