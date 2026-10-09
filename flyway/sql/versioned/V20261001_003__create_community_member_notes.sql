-- Community-scoped member notes.
-- Notes are separate from legacy global user_notes and are never hard-deleted by this schema.

CREATE TABLE IF NOT EXISTS `community_member_notes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `user_id` INT(11) NOT NULL,
    `author_user_id` INT(11) NOT NULL,
    `updated_by_user_id` INT(11) NOT NULL,
    `content` TEXT NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    `archived_at` DATETIME(6) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_cmn_member_archive_created`
        (`community_id`, `user_id`, `archived_at`, `created_at`, `id`),
    KEY `idx_cmn_author_created` (`author_user_id`, `created_at`),
    KEY `idx_cmn_updated_by` (`updated_by_user_id`),
    CONSTRAINT `fk_cmn_member_same_community`
        FOREIGN KEY (`community_id`, `user_id`)
        REFERENCES `user_community_status` (`community_id`, `user_id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cmn_author`
        FOREIGN KEY (`author_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cmn_updated_by`
        FOREIGN KEY (`updated_by_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_general_ci;
