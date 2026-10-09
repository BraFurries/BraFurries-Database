-- Community lifecycle and external-network synchronization foundation.
-- This is additive: existing configured Portarias remain enabled, unconfigured
-- rows remain disabled, and existing membership records retain unknown approval applicability.

ALTER TABLE `portaria_base_config`
    ADD COLUMN `portaria_enabled` TINYINT(1) NOT NULL DEFAULT 0;

-- Preserve the legacy meaning of "configured": an existing Portaria flow means
-- the Portaria was operational before this explicit lifecycle flag existed.
UPDATE `portaria_base_config` AS p
SET p.`portaria_enabled` = 1
WHERE EXISTS (
    SELECT 1
    FROM `form_flows` AS f
    WHERE f.`server_guild_id` = p.`server_guild_id`
      AND LOWER(f.`type`) = 'portaria'
);

ALTER TABLE `user_community_status`
    ADD COLUMN `approval_required` TINYINT(1) NULL,
    ADD COLUMN `display_name` VARCHAR(100) NULL;

CREATE TABLE IF NOT EXISTS `community_network_sync_runs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `network_type` VARCHAR(32) NOT NULL,
    `external_network_id` BIGINT(20) NOT NULL,
    `trigger` VARCHAR(32) NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'QUEUED',
    `started_at` DATETIME(6) DEFAULT NULL,
    `completed_at` DATETIME(6) DEFAULT NULL,
    `observed_members` INT UNSIGNED DEFAULT NULL,
    `updated_members` INT UNSIGNED DEFAULT NULL,
    `error_code` VARCHAR(64) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_cnsr_community_network` (`community_id`, `network_type`, `external_network_id`),
    KEY `idx_cnsr_community_status_started` (`community_id`, `status`, `started_at`),
    KEY `idx_cnsr_network_status_id` (`network_type`, `status`, `id`),
    CONSTRAINT `fk_cnsr_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cnsr_trigger`
        CHECK (`trigger` IN ('GUILD_JOIN', 'STARTUP', 'PERIODIC', 'MANUAL', 'OWNERSHIP_CHANGE')),
    CONSTRAINT `ck_cnsr_status`
        CHECK (`status` IN ('QUEUED', 'RUNNING', 'SUCCESS', 'FAILED')),
    CONSTRAINT `ck_cnsr_observed_members`
        CHECK (`observed_members` IS NULL OR `observed_members` >= 0),
    CONSTRAINT `ck_cnsr_updated_members`
        CHECK (`updated_members` IS NULL OR `updated_members` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
