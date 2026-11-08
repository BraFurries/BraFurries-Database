-- Independent, one-use proof for reactivating a disabled OAuth login from
-- an authenticated local account. This challenge cannot create an identity or
-- transfer an existing provider subject to another site account.
CREATE TABLE `user_social_login_proofs` (
    `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    `ticket_hash` CHAR(64) NOT NULL,
    `requesting_user_id` INT(11) NOT NULL,
    `provider` VARCHAR(16) NOT NULL,
    `status` VARCHAR(16) NOT NULL,
    `provider_subject` VARCHAR(128) NULL,
    `expires_at` DATETIME(6) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `verified_at` DATETIME(6) NULL,
    `consumed_at` DATETIME(6) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_social_login_proof_ticket` (`ticket_hash`),
    KEY `idx_social_login_proof_owner` (`requesting_user_id`, `status`),
    KEY `idx_social_login_proof_expiry` (`expires_at`),
    CONSTRAINT `fk_social_login_proof_owner`
        FOREIGN KEY (`requesting_user_id`) REFERENCES `users` (`id`)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_social_login_proof_provider`
        CHECK (`provider` IN ('google', 'discord')),
    CONSTRAINT `ck_social_login_proof_status`
        CHECK (`status` IN ('STARTED', 'VERIFIED', 'CONSUMED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
