-- Community Team role assignments.
-- Requires user_community_status to be structurally unique by (community_id, user_id)
-- as formalized by the preceding Community membership migration.
CREATE TABLE IF NOT EXISTS `community_team_role_assignments` (
    `community_id` INT(11) NOT NULL,
    `role_id` INT(11) NOT NULL,
    `user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`community_id`, `role_id`, `user_id`),
    KEY `idx_ctra_community_user` (`community_id`, `user_id`),
    CONSTRAINT `fk_ctra_role_same_community`
        FOREIGN KEY (`community_id`, `role_id`)
        REFERENCES `community_team_roles` (`community_id`, `id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_ctra_member_same_community`
        FOREIGN KEY (`community_id`, `user_id`)
        REFERENCES `user_community_status` (`community_id`, `user_id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
