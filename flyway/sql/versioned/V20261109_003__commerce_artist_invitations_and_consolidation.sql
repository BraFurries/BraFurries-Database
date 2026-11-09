-- BraFurries-only artist records, staff-issued invitations and audited consolidation.
-- IMPORTANT: no spontaneous user-driven claim by artist IDs or public artwork search.
-- The commercial placeholder has users.id but no credentials/Community identity.
-- Existing contract author/signatory information remains immutable in snapshots.
-- Production adopts this exact reviewed SQL MANUALLY after backup and preflight.

CREATE TABLE `commerce_artist_profiles` (
    `user_id` INT(11) NOT NULL,
    `artist_name` VARCHAR(120) NOT NULL,
    `telegram_handle` VARCHAR(100) NULL,
    `instagram_handle` VARCHAR(100) NULL,
    `contact_email` VARCHAR(255) NULL,
    `internal_notes` TEXT NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`user_id`),
    KEY `idx_cap_artist_name` (`artist_name`),
    KEY `fk_cap_creator` (`created_by_user_id`),
    CONSTRAINT `fk_cap_user` FOREIGN KEY (`user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cap_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cap_name` CHECK (CHAR_LENGTH(TRIM(`artist_name`)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Token and separately shared confirmation code are generated with SecureRandom.
-- Only their SHA256 hashes are stored. The UI must never expose them after creation.
-- No raw token/code in audit or logs. A separate prior-known channel is required
-- to deliver the code (a forwarded invitation URL alone does not grant ownership).
CREATE TABLE `commerce_artist_invitations` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `artist_user_id` INT(11) NOT NULL,
    `token_hash` CHAR(64) NOT NULL,
    `code_hash` CHAR(64) NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'ACTIVE',
    `failed_attempts` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `expires_at` DATETIME(6) NOT NULL,
    `issued_by_user_id` INT(11) NOT NULL,
    `issued_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `consumed_by_user_id` INT(11) NULL,
    `consumed_at` DATETIME(6) NULL,
    `revoked_by_user_id` INT(11) NULL,
    `revoked_at` DATETIME(6) NULL,
    -- Not a users.id foreign key; omit _user_id naming so the live
    -- consolidation reference scanner does not mistake this generated key
    -- for an independent ownership relationship.
    `active_artist_key` INT(11) AS
        (CASE WHEN `status`='ACTIVE' THEN `artist_user_id` ELSE NULL END) PERSISTENT,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cai_token` (`token_hash`),
    UNIQUE KEY `uq_cai_active_artist` (`active_artist_key`),
    KEY `idx_cai_artist` (`artist_user_id`,`issued_at`),
    KEY `idx_cai_expire` (`status`,`expires_at`),
    KEY `fk_cai_issuer` (`issued_by_user_id`),
    KEY `fk_cai_consumer` (`consumed_by_user_id`),
    KEY `fk_cai_revoker` (`revoked_by_user_id`),
    CONSTRAINT `fk_cai_artist` FOREIGN KEY (`artist_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cai_issuer` FOREIGN KEY (`issued_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cai_consumer` FOREIGN KEY (`consumed_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cai_revoker` FOREIGN KEY (`revoked_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cai_token_hashes` CHECK (
        `token_hash` REGEXP '^[0-9a-f]{64}$'
        AND `code_hash` REGEXP '^[0-9a-f]{64}$'
    ),
    CONSTRAINT `ck_cai_status` CHECK (`status` IN ('ACTIVE','USED','REVOKED','BLOCKED')),
    CONSTRAINT `ck_cai_attempts` CHECK (`failed_attempts`<=5),
    CONSTRAINT `ck_cai_consumption` CHECK (
        (`status`='USED' AND `consumed_by_user_id` IS NOT NULL
            AND `consumed_at` IS NOT NULL)
        OR (`status`<>'USED' AND `consumed_by_user_id` IS NULL
            AND `consumed_at` IS NULL)
    ),
    CONSTRAINT `ck_cai_revocation` CHECK (
        (`status`='REVOKED' AND `revoked_by_user_id` IS NOT NULL
            AND `revoked_at` IS NOT NULL)
        OR (`status`<>'REVOKED' AND `revoked_by_user_id` IS NULL
            AND `revoked_at` IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
-- When an invited artist already has a main website account, all current
-- commerce ownership FKs move to it atomically. The old users row remains
-- only as an unusable provenance alias, not as another usable account.
CREATE TABLE `commerce_artist_consolidations` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `invitation_id` BIGINT UNSIGNED NOT NULL,
    `original_user_id` INT(11) NOT NULL,
    `canonical_user_id` INT(11) NOT NULL,
    `consolidation_kind` VARCHAR(20) NOT NULL,
    `artworks_moved` INT UNSIGNED NOT NULL DEFAULT 0,
    `contracts_moved` INT UNSIGNED NOT NULL DEFAULT 0,
    `accruals_moved` INT UNSIGNED NOT NULL DEFAULT 0,
    `settlements_moved` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cacon_invitation` (`invitation_id`),
    UNIQUE KEY `uq_cacon_original` (`original_user_id`),
    KEY `idx_cacon_canonical` (`canonical_user_id`),
    CONSTRAINT `fk_cacon_invite` FOREIGN KEY (`invitation_id`)
        REFERENCES `commerce_artist_invitations` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cacon_original` FOREIGN KEY (`original_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cacon_canonical` FOREIGN KEY (`canonical_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cacon_kind` CHECK (`consolidation_kind` IN ('ACTIVATION','MERGE')),
    CONSTRAINT `ck_cacon_distinct` CHECK (
        (`consolidation_kind`='ACTIVATION' AND `original_user_id`=`canonical_user_id`)
        OR (`consolidation_kind`='MERGE' AND `original_user_id`<>`canonical_user_id`)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- The original signed contract signatory is immutable historical evidence,
-- while artist_user_id is the current canonical commercial owner.
-- A composite FK on (artwork_id, artist_user_id) would otherwise make a
-- legitimate transactional reassignment impossible under MariaDB RESTRICT.
ALTER TABLE `commerce_artwork_contracts`
    ADD COLUMN `signed_artist_user_id` INT(11) NULL AFTER `artist_user_id`;

UPDATE `commerce_artwork_contracts`
   SET `signed_artist_user_id`=`artist_user_id`
 WHERE `signed_artist_user_id` IS NULL;

ALTER TABLE `commerce_artwork_contracts`
    MODIFY `signed_artist_user_id` INT(11) NOT NULL,
    ADD KEY `idx_cac_signed_artist` (`signed_artist_user_id`),
    ADD CONSTRAINT `fk_cac_signed_artist` FOREIGN KEY (`signed_artist_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    DROP FOREIGN KEY `fk_cac_artwork_artist`,
    ADD CONSTRAINT `fk_cac_artwork_only` FOREIGN KEY (`artwork_id`)
        REFERENCES `commerce_artworks` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT;

-- Existing table CHECKs and FKs remain untouched. The API must enforce that
-- newly signed contracts have the same owner as their artwork at insert time.
-- Historical financial amounts and signed document bytes are never rewritten.
