-- Enforce the V1 Backup policy and add durable operation progress telemetry.
-- Existing snapshot rows are preserved here. Runtime replacement keeps only the
-- newest manual and periodic snapshot after the next successful capture.

ALTER TABLE `backup_server_settings`
    MODIFY COLUMN `max_normal_backups` INT NOT NULL DEFAULT 1,
    MODIFY COLUMN `max_periodic_backups` INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS `bot_removed_at` DATETIME(6) NULL DEFAULT NULL AFTER `periodicity_frequency`,
    ADD COLUMN IF NOT EXISTS `purge_after` DATETIME(6) NULL DEFAULT NULL AFTER `bot_removed_at`,
    ADD INDEX IF NOT EXISTS `idx_backup_server_settings_purge_after` (`purge_after`);

UPDATE `backup_server_settings`
SET `max_normal_backups` = 1,
    `max_periodic_backups` = 1;

ALTER TABLE `backup_restore_operations`
    ADD COLUMN IF NOT EXISTS `progress_current` INT NOT NULL DEFAULT 0 AFTER `error_code`,
    ADD COLUMN IF NOT EXISTS `progress_total` INT NOT NULL DEFAULT 0 AFTER `progress_current`,
    ADD COLUMN IF NOT EXISTS `current_step` VARCHAR(96) NULL DEFAULT NULL AFTER `progress_total`;

CREATE TABLE IF NOT EXISTS `backup_snapshot_operations` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `guild_id` BIGINT NOT NULL,
    `operation_key` VARCHAR(96) NOT NULL,
    `backup_type` VARCHAR(20) NOT NULL,
    `requested_name` VARCHAR(255) NOT NULL,
    `actor_discord_user_id` BIGINT NULL DEFAULT NULL,
    `actor_user_id` INT NULL DEFAULT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    `backup_id` INT NULL DEFAULT NULL,
    `progress_current` INT NOT NULL DEFAULT 0,
    `progress_total` INT NOT NULL DEFAULT 0,
    `current_step` VARCHAR(96) NULL DEFAULT NULL,
    `result_json` LONGTEXT NULL,
    `error_code` VARCHAR(96) NULL DEFAULT NULL,
    `requested_audited_at` DATETIME(6) NULL DEFAULT NULL,
    `completion_audited_at` DATETIME(6) NULL DEFAULT NULL,
    `started_at` DATETIME(6) NULL DEFAULT NULL,
    `finished_at` DATETIME(6) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_backup_snapshot_guild_operation_key` (`guild_id`, `operation_key`),
    KEY `idx_backup_snapshot_guild_status` (`guild_id`, `status`, `id`),
    KEY `idx_backup_snapshot_backup` (`guild_id`, `backup_id`),
    CONSTRAINT `fk_backup_snapshot_actor`
        FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT `ck_backup_snapshot_type`
        CHECK (`backup_type` IN ('normal', 'periodic')),
    CONSTRAINT `ck_backup_snapshot_status`
        CHECK (`status` IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'PARTIAL', 'FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `backup_operation_steps` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `guild_id` BIGINT NOT NULL,
    `operation_kind` VARCHAR(20) NOT NULL,
    `operation_id` BIGINT NOT NULL,
    `step_code` VARCHAR(96) NOT NULL,
    `step_status` VARCHAR(20) NOT NULL,
    `message` VARCHAR(512) NOT NULL,
    `progress_current` INT NOT NULL DEFAULT 0,
    `progress_total` INT NOT NULL DEFAULT 0,
    `detail_json` LONGTEXT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_backup_operation_steps_operation`
        (`guild_id`, `operation_kind`, `operation_id`, `id`),
    CONSTRAINT `ck_backup_operation_steps_kind`
        CHECK (`operation_kind` IN ('SNAPSHOT', 'RESTORE')),
    CONSTRAINT `ck_backup_operation_steps_status`
        CHECK (`step_status` IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'SKIPPED', 'FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
