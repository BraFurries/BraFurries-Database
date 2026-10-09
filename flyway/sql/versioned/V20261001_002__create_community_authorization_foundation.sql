-- Community-scoped authorization foundation.
-- Community remains the tenant. Discord ownership/administration stays a separate domain.
-- Existing Communities are intentionally left without an owner until claimed or assigned by API flows.

ALTER TABLE `communities`
    ADD COLUMN `owner_user_id` INT(11) NULL,
    ADD KEY `idx_communities_owner_user` (`owner_user_id`),
    ADD CONSTRAINT `fk_communities_owner_user`
        FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS `community_team_role_capabilities` (
    `community_id` INT(11) NOT NULL,
    `role_id` INT(11) NOT NULL,
    `capability` VARCHAR(64) NOT NULL,
    `granted_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`community_id`, `role_id`, `capability`),
    KEY `idx_ctrc_grantor` (`granted_by_user_id`, `created_at`),
    CONSTRAINT `fk_ctrc_role_same_community`
        FOREIGN KEY (`community_id`, `role_id`)
        REFERENCES `community_team_roles` (`community_id`, `id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_ctrc_grantor`
        FOREIGN KEY (`granted_by_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `community_user_capability_grants` (
    `community_id` INT(11) NOT NULL,
    `user_id` INT(11) NOT NULL,
    `capability` VARCHAR(64) NOT NULL,
    `granted_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`community_id`, `user_id`, `capability`),
    KEY `idx_cucg_grantor` (`granted_by_user_id`, `created_at`),
    CONSTRAINT `fk_cucg_member_same_community`
        FOREIGN KEY (`community_id`, `user_id`)
        REFERENCES `user_community_status` (`community_id`, `user_id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cucg_grantor`
        FOREIGN KEY (`granted_by_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `community_audit_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `actor_user_id` INT(11) NOT NULL,
    `action` VARCHAR(64) NOT NULL,
    `target_type` VARCHAR(64) DEFAULT NULL,
    `target_id` VARCHAR(128) DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_cal_community_created` (`community_id`, `created_at`, `id`),
    KEY `idx_cal_actor_created` (`actor_user_id`, `created_at`),
    CONSTRAINT `fk_cal_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cal_actor`
        FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
