-- BraFurries social identity consolidation. DDL belongs to Database.
-- Never infer ownership from matching names, Discord server membership or e-mail alone.
-- An absorbed user remains as an inoperative provenance alias, not a login identity.
ALTER TABLE `users`
    ADD COLUMN `merged_into_user_id` INT(11) NULL,
    ADD COLUMN `auth_version` BIGINT(20) NOT NULL DEFAULT 0,
    ADD KEY `idx_users_merged_into` (`merged_into_user_id`),
    ADD CONSTRAINT `fk_users_merged_into` FOREIGN KEY (`merged_into_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT;

-- Provider subjects, not e-mail strings, are the stable OAuth identifiers.
CREATE TABLE `user_social_identities` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `provider` VARCHAR(16) NOT NULL,
    `provider_subject` VARCHAR(128) NOT NULL,
    `verified_email` VARCHAR(255) NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `last_verified_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_social_provider_subject` (`provider`, `provider_subject`),
    UNIQUE KEY `uq_social_user_provider` (`user_id`, `provider`),
    CONSTRAINT `fk_social_identity_user` FOREIGN KEY (`user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_social_provider` CHECK (`provider` IN ('google', 'discord'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Each authenticated session may initiate an expiring, single-use Discord proof.
-- Store only a SHA-256 hash of the random token; never put bearer/JWT in a link.
CREATE TABLE `user_social_link_challenges` (
    `token_hash` CHAR(64) NOT NULL,
    `initiated_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `expires_at` DATETIME(6) NOT NULL,
    `consumed_at` DATETIME(6) NULL,
    PRIMARY KEY (`token_hash`),
    KEY `idx_social_link_expires` (`expires_at`),
    CONSTRAINT `fk_social_link_initiator` FOREIGN KEY (`initiated_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Audit is immutable; preserve original and canonical IDs for forensic review.
-- Absorbed users are not deleted because existing historical actor FKs refer to them.
CREATE TABLE `user_account_consolidations` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `canonical_user_id` INT(11) NOT NULL,
    `absorbed_user_id` INT(11) NOT NULL,
    `proved_discord_user_id` BIGINT(20) NOT NULL,
    `initiated_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_user_consolidation_absorbed` (`absorbed_user_id`),
    KEY `idx_user_consolidation_canonical` (`canonical_user_id`),
    CONSTRAINT `fk_user_consolidation_canonical` FOREIGN KEY (`canonical_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_user_consolidation_absorbed` FOREIGN KEY (`absorbed_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_user_consolidation_initiator` FOREIGN KEY (`initiated_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_user_consolidation_distinct`
        CHECK (`canonical_user_id` <> `absorbed_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
