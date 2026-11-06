-- Immutable per-Community provenance for membership ownership transferred
-- during an independently verified, audited account consolidation.
-- DDL authority: BraFurries-Database. No production data is modified here.
CREATE TABLE `user_community_membership_transfers` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `consolidation_id` BIGINT(20) NOT NULL,
    `community_status_id` INT(11) NOT NULL,
    `community_id` INT(11) NOT NULL,
    `from_user_id` INT(11) NOT NULL,
    `to_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_member_transfer_consolidation_status` (
        `consolidation_id`, `community_status_id`),
    KEY `idx_member_transfer_community_time` (`community_id`, `created_at`),
    KEY `idx_member_transfer_status` (`community_status_id`),
    KEY `idx_member_transfer_from` (`from_user_id`),
    KEY `idx_member_transfer_to` (`to_user_id`),
    CONSTRAINT `fk_member_transfer_consolidation`
        FOREIGN KEY (`consolidation_id`) REFERENCES `user_account_consolidations` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_member_transfer_status`
        FOREIGN KEY (`community_status_id`) REFERENCES `user_community_status` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_member_transfer_community`
        FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_member_transfer_from`
        FOREIGN KEY (`from_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_member_transfer_to`
        FOREIGN KEY (`to_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_member_transfer_distinct_users`
        CHECK (`from_user_id` <> `to_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
