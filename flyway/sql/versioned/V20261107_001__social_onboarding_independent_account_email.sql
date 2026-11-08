-- An OAuth subject belongs to the external provider, never to the site e-mail.
-- Keep the verified Discord identity and its historical Community references
-- even if this provider is no longer authorized to sign in to BraFurries.
ALTER TABLE `user_social_identities`
    ADD COLUMN `login_enabled` TINYINT(1) NOT NULL DEFAULT 1;

-- Cross-replica, single-use onboarding state. Store only a SHA-256 hash of
-- the opaque OAuth proof token. The provider e-mail is optional metadata for
-- user-editable suggestion; it never creates or verifies the site's e-mail.
CREATE TABLE `user_social_onboarding_challenges` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `token_hash` CHAR(64) NOT NULL,
    `provider` VARCHAR(16) NOT NULL,
    `provider_subject` VARCHAR(128) NOT NULL,
    `suggested_email` VARCHAR(255) NULL,
    `display_name` VARCHAR(32) NULL,
    `expires_at` DATETIME(6) NOT NULL,
    `consumed_at` DATETIME(6) NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_social_onboarding_token_hash` (`token_hash`),
    KEY `idx_social_onboarding_subject` (`provider`, `provider_subject`),
    KEY `idx_social_onboarding_expiry` (`expires_at`),
    CONSTRAINT `ck_social_onboarding_provider`
        CHECK (`provider` IN ('google', 'discord'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
