-- Network-scoped Community membership state and transition history.
-- State is populated only from authoritative network observations. Existing
-- user_community_status rows are intentionally NOT copied into network rows.

ALTER TABLE `community_discord`
    ADD COLUMN `membership_sync_state` VARCHAR(32) NOT NULL DEFAULT 'RECONCILIATION_REQUIRED',
    ADD COLUMN `last_full_reconciliation_at` DATETIME(6) NULL,
    ADD COLUMN `last_membership_event_at` DATETIME(6) NULL,
    ADD CONSTRAINT `ck_community_discord_membership_sync_state`
        CHECK (`membership_sync_state` IN (
            'RECONCILIATION_REQUIRED',
            'RECONCILING',
            'HEALTHY',
            'DEGRADED'
        ));

ALTER TABLE `community_network_sync_runs`
    DROP CONSTRAINT `ck_cnsr_trigger`,
    ADD CONSTRAINT `ck_cnsr_trigger`
        CHECK (`trigger` IN (
            'GUILD_JOIN',
            'STARTUP',
            'PERIODIC',
            'MANUAL',
            'OWNERSHIP_CHANGE',
            'DRIFT',
            'RECOVERY'
        ));

CREATE TABLE `community_network_member_status` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `network_type` VARCHAR(32) NOT NULL,
    `external_network_id` BIGINT(20) NOT NULL,
    `user_id` INT(11) NOT NULL,
    `is_present` TINYINT(1) NOT NULL DEFAULT 0,
    `first_known_join_at` DATETIME(6) NULL,
    `first_known_join_source` VARCHAR(32) NULL,
    `last_join_at` DATETIME(6) NULL,
    `last_join_source` VARCHAR(32) NULL,
    `current_presence_since` DATETIME(6) NULL,
    `left_at` DATETIME(6) NULL,
    `last_observed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `last_sync_run_id` BIGINT UNSIGNED NULL,
    `approval_required` TINYINT(1) NULL,
    `approved` TINYINT(1) NULL,
    `approved_at` DATETIME(6) NULL,
    `display_name` VARCHAR(100) NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_cnms_network_user`
        (`network_type`, `external_network_id`, `user_id`),
    KEY `idx_cnms_community_user_present`
        (`community_id`, `user_id`, `is_present`),
    KEY `idx_cnms_network_present_user`
        (`network_type`, `external_network_id`, `is_present`, `user_id`),
    KEY `idx_cnms_user_network`
        (`user_id`, `network_type`, `external_network_id`),
    KEY `idx_cnms_network_sync`
        (`network_type`, `external_network_id`, `last_sync_run_id`, `is_present`),
    CONSTRAINT `fk_cnms_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cnms_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cnms_last_sync_run`
        FOREIGN KEY (`last_sync_run_id`) REFERENCES `community_network_sync_runs` (`id`)
        ON UPDATE RESTRICT ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_network_member_events` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `network_type` VARCHAR(32) NOT NULL,
    `external_network_id` BIGINT(20) NOT NULL,
    `user_id` INT(11) NOT NULL,
    `event_type` VARCHAR(32) NOT NULL,
    `occurred_at` DATETIME(6) NOT NULL,
    `observed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `source` VARCHAR(32) NOT NULL,
    `sync_run_id` BIGINT UNSIGNED NULL,
    PRIMARY KEY (`id`),
    KEY `idx_cnme_network_user_time`
        (`network_type`, `external_network_id`, `user_id`, `occurred_at`, `id`),
    KEY `idx_cnme_community_user_time`
        (`community_id`, `user_id`, `occurred_at`, `id`),
    KEY `idx_cnme_sync_run` (`sync_run_id`),
    CONSTRAINT `fk_cnme_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cnme_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cnme_sync_run`
        FOREIGN KEY (`sync_run_id`) REFERENCES `community_network_sync_runs` (`id`)
        ON UPDATE RESTRICT ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_general_ci;
