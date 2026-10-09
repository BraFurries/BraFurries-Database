-- Structural adoption only. The legacy account split was performed manually and is intentionally absent.
CREATE TABLE IF NOT EXISTS `user_identity_links` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `primary_user_id` INT(11) NOT NULL,
    `linked_user_id` INT(11) NOT NULL,
    `status` VARCHAR(16) NOT NULL,
    `link_source` VARCHAR(32) NOT NULL,
    `reason` VARCHAR(500) DEFAULT NULL,
    `linked_by_user_id` INT(11) DEFAULT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `revoked_at` DATETIME(6) DEFAULT NULL,
    `revoked_by_user_id` INT(11) DEFAULT NULL,
    `revocation_reason` VARCHAR(500) DEFAULT NULL,
    `active_linked_user_id` INT(11)
        GENERATED ALWAYS AS (
            CASE WHEN `revoked_at` IS NULL THEN `linked_user_id` ELSE NULL END
        ) STORED,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_identity_links_active_linked_user` (`active_linked_user_id`),
    KEY `idx_user_identity_links_primary_active` (`primary_user_id`, `revoked_at`),
    KEY `idx_user_identity_links_linked_active` (`linked_user_id`, `revoked_at`),
    KEY `idx_user_identity_links_linked_by` (`linked_by_user_id`),
    KEY `idx_user_identity_links_revoked_by` (`revoked_by_user_id`),
    CONSTRAINT `chk_user_identity_links_distinct_users`
        CHECK (`primary_user_id` <> `linked_user_id`),
    CONSTRAINT `chk_user_identity_links_status`
        CHECK (`status` IN ('CONFIRMED', 'SUSPECTED')),
    CONSTRAINT `chk_user_identity_links_source`
        CHECK (`link_source` IN ('ADMIN', 'LEGACY_SPLIT', 'SOCIAL')),
    CONSTRAINT `fk_user_identity_links_primary_user`
        FOREIGN KEY (`primary_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_user_identity_links_linked_user`
        FOREIGN KEY (`linked_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_user_identity_links_linked_by_user`
        FOREIGN KEY (`linked_by_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_user_identity_links_revoked_by_user`
        FOREIGN KEY (`revoked_by_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
