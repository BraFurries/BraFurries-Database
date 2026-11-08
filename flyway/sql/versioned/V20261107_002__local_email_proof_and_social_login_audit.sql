-- Positive local e-mail confirmation is different from provider email_verified.
-- Existing rows remain NULL: historic imported e-mails cannot be trusted or
-- silently backfilled. Legacy users must explicitly confirm their chosen
-- BraFurries e-mail before changing their remaining login methods.
ALTER TABLE `users`
    ADD COLUMN `email_verified_at` DATETIME(6) NULL;

-- Durable, immutable audit for OAuth login-permission changes.
-- No provider tokens, e-mails or Discord subjects are stored here.
CREATE TABLE `user_social_login_events` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `social_identity_id` BIGINT(20) NOT NULL,
    `provider` VARCHAR(16) NOT NULL,
    `previous_login_enabled` TINYINT(1) NOT NULL,
    `next_login_enabled` TINYINT(1) NOT NULL,
    `previous_auth_version` BIGINT(20) NOT NULL,
    `next_auth_version` BIGINT(20) NOT NULL,
    `occurred_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_social_login_event_user_time` (`user_id`, `occurred_at`),
    KEY `idx_social_login_event_identity` (`social_identity_id`),
    CONSTRAINT `fk_social_login_event_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_social_login_event_identity`
        FOREIGN KEY (`social_identity_id`) REFERENCES `user_social_identities` (`id`)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_social_login_event_provider`
        CHECK (`provider` IN ('google', 'discord')),
    CONSTRAINT `ck_social_login_event_auth_version`
        CHECK (`next_auth_version` = `previous_auth_version` + 1),
    CONSTRAINT `ck_social_login_event_state_changed`
        CHECK (`previous_login_enabled` <> `next_login_enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
