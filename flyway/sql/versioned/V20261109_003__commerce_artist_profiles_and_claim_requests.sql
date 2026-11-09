-- BraFurries-only commercial artists and guarded self-service ownership requests.
-- No community_id: this is NOT a multi-Community product.
-- Retain the existing users.id foreign keys on artworks, contracts, royalty
-- accruals, period locks, statements and payments. Do not rewrite history.
-- A commercial artist user may be an inert user row without credentials,
-- memberships, OAuth identities or Discord/Telegram identities.
-- Contact channels stored here are informational, NEVER login proof.
--
-- Production has no official Flyway baseline; manual rollout requires
-- operator backup, schema preflight and reviewed exact SQL as an exception.

CREATE TABLE `commerce_artist_profiles` (
    `user_id` INT(11) NOT NULL,
    `artist_name` VARCHAR(120) NOT NULL,
    `telegram_handle` VARCHAR(100) NULL,
    `instagram_handle` VARCHAR(100) NULL,
    `contact_email` VARCHAR(255) NULL,
    `internal_notes` TEXT NULL,
    `claimed_by_user_id` INT(11) NULL,
    `claimed_at` DATETIME(6) NULL,
    `claim_approved_by_user_id` INT(11) NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`user_id`),
    KEY `idx_cap_artist_name` (`artist_name`),
    KEY `idx_cap_claimed_by` (`claimed_by_user_id`),
    KEY `fk_cap_creator` (`created_by_user_id`),
    KEY `fk_cap_approver` (`claim_approved_by_user_id`),
    CONSTRAINT `fk_cap_user` FOREIGN KEY (`user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cap_claimed` FOREIGN KEY (`claimed_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cap_approver` FOREIGN KEY (`claim_approved_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cap_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cap_name` CHECK (CHAR_LENGTH(TRIM(`artist_name`)) > 0),
    CONSTRAINT `ck_cap_claim_state` CHECK (
        (`claimed_by_user_id` IS NULL AND `claimed_at` IS NULL
            AND `claim_approved_by_user_id` IS NULL)
        OR (`claimed_by_user_id` IS NOT NULL AND `claimed_at` IS NOT NULL
            AND `claim_approved_by_user_id` IS NOT NULL)
    ),
    CONSTRAINT `ck_cap_no_self_claim` CHECK (
        `claimed_by_user_id` IS NULL OR `claimed_by_user_id` <> `user_id`
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- One PENDING request per artist and per requesting account. Historical
-- APPROVED, REJECTED and REVOKED requests are retained for audit. A staff
-- member can never grant a claim using ARTWORKS_MANAGE alone: API requires owner.
CREATE TABLE `commerce_artist_claim_requests` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `artist_user_id` INT(11) NOT NULL,
    `requester_user_id` INT(11) NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'PENDING',
    `requester_message` VARCHAR(1000) NULL,
    `verification_method` VARCHAR(20) NULL,
    `review_notes` VARCHAR(1000) NULL,
    `reviewed_by_user_id` INT(11) NULL,
    `reviewed_at` DATETIME(6) NULL,
    `revoked_by_user_id` INT(11) NULL,
    `revoked_at` DATETIME(6) NULL,
    `revocation_reason` VARCHAR(1000) NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    `pending_artist_user_id` INT(11) AS
        (CASE WHEN `status` = 'PENDING' THEN `artist_user_id` ELSE NULL END) PERSISTENT,
    `pending_requester_user_id` INT(11) AS
        (CASE WHEN `status` = 'PENDING' THEN `requester_user_id` ELSE NULL END) PERSISTENT,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cacr_pending_artist` (`pending_artist_user_id`),
    UNIQUE KEY `uq_cacr_pending_requester` (`pending_requester_user_id`),
    KEY `idx_cacr_artist_created` (`artist_user_id`,`created_at`),
    KEY `idx_cacr_requester_created` (`requester_user_id`,`created_at`),
    KEY `idx_cacr_status_created` (`status`,`created_at`),
    KEY `fk_cacr_reviewer` (`reviewed_by_user_id`),
    KEY `fk_cacr_revoker` (`revoked_by_user_id`),
    CONSTRAINT `fk_cacr_artist` FOREIGN KEY (`artist_user_id`)
        REFERENCES `commerce_artist_profiles` (`user_id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cacr_requester` FOREIGN KEY (`requester_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cacr_reviewer` FOREIGN KEY (`reviewed_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cacr_revoker` FOREIGN KEY (`revoked_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cacr_people` CHECK (`artist_user_id` <> `requester_user_id`),
    CONSTRAINT `ck_cacr_status` CHECK (
        `status` IN ('PENDING','APPROVED','REJECTED','REVOKED')
    ),
    CONSTRAINT `ck_cacr_review` CHECK (
        (`status`='PENDING' AND `reviewed_by_user_id` IS NULL
            AND `reviewed_at` IS NULL AND `verification_method` IS NULL)
        OR (`status`<>'PENDING' AND `reviewed_by_user_id` IS NOT NULL
            AND `reviewed_at` IS NOT NULL)
    ),
    CONSTRAINT `ck_cacr_method` CHECK (
        `verification_method` IS NULL OR `verification_method`
        IN ('TELEGRAM','EMAIL','IN_PERSON','OTHER')
    ),
    CONSTRAINT `ck_cacr_revocation` CHECK (
        (`status`='REVOKED' AND `revoked_by_user_id` IS NOT NULL
            AND `revoked_at` IS NOT NULL AND `revocation_reason` IS NOT NULL)
        OR (`status`<>'REVOKED' AND `revoked_by_user_id` IS NULL
            AND `revoked_at` IS NULL AND `revocation_reason` IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
