-- Replace the retired primary/linked star model with an undirected identity edge.
-- Preflight must prove that no two active rows describe the same unordered pair.
ALTER TABLE `user_identity_links`
    DROP FOREIGN KEY `fk_user_identity_links_primary_user`,
    DROP FOREIGN KEY `fk_user_identity_links_linked_user`,
    DROP CONSTRAINT `chk_user_identity_links_distinct_users`,
    DROP INDEX `uk_user_identity_links_active_linked_user`,
    DROP INDEX `idx_user_identity_links_primary_active`,
    DROP INDEX `idx_user_identity_links_linked_active`,
    DROP COLUMN `active_linked_user_id`,
    CHANGE COLUMN `primary_user_id` `user_a_id` INT(11) NOT NULL,
    CHANGE COLUMN `linked_user_id` `user_b_id` INT(11) NOT NULL,
    ADD COLUMN `active_user_low_id` INT(11)
        GENERATED ALWAYS AS (
            CASE
                WHEN `revoked_at` IS NULL THEN LEAST(`user_a_id`, `user_b_id`)
                ELSE NULL
            END
        ) STORED,
    ADD COLUMN `active_user_high_id` INT(11)
        GENERATED ALWAYS AS (
            CASE
                WHEN `revoked_at` IS NULL THEN GREATEST(`user_a_id`, `user_b_id`)
                ELSE NULL
            END
        ) STORED,
    ADD UNIQUE KEY `uk_user_identity_links_active_pair`
        (`active_user_low_id`, `active_user_high_id`),
    ADD KEY `idx_user_identity_links_user_a_active` (`user_a_id`, `revoked_at`),
    ADD KEY `idx_user_identity_links_user_b_active` (`user_b_id`, `revoked_at`),
    ADD CONSTRAINT `chk_user_identity_links_distinct_users`
        CHECK (`user_a_id` <> `user_b_id`),
    ADD CONSTRAINT `fk_user_identity_links_user_a`
        FOREIGN KEY (`user_a_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT `fk_user_identity_links_user_b`
        FOREIGN KEY (`user_b_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT;
