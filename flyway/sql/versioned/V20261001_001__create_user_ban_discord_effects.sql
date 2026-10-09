-- Discord-side effects produced by one administrative user_bans action.
-- Identity-cluster resolution remains an API responsibility; this table only
-- records the concrete, tenant-scoped effects attempted by Coddy.
CREATE TABLE IF NOT EXISTS `user_ban_discord_effects` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ban_id` INT(11) NOT NULL,
    `identity_user_id` INT(11) NOT NULL,
    `discord_user_id` BIGINT(20) NOT NULL,
    `is_origin` TINYINT(1) NOT NULL DEFAULT 0,
    `outcome` VARCHAR(32) NOT NULL,
    `error_code` VARCHAR(64) DEFAULT NULL,
    `attempted_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `reverted_at` DATETIME(6) DEFAULT NULL,
    `revert_outcome` VARCHAR(32) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_user_ban_effect_ban_discord` (`ban_id`, `discord_user_id`),
    KEY `idx_user_ban_effect_discord` (`discord_user_id`, `ban_id`),
    KEY `idx_user_ban_effect_identity` (`identity_user_id`, `ban_id`),
    CONSTRAINT `ck_user_ban_effect_is_origin` CHECK (`is_origin` IN (0, 1)),
    CONSTRAINT `ck_user_ban_effect_outcome` CHECK (`outcome` IN (
        'APPLIED', 'ALREADY_BANNED', 'NOT_FOUND', 'FORBIDDEN', 'FAILED'
    )),
    CONSTRAINT `ck_user_ban_effect_revert_outcome` CHECK (
        `revert_outcome` IS NULL OR `revert_outcome` IN (
            'REVERTED', 'ALREADY_UNBANNED', 'NOT_FOUND', 'FORBIDDEN', 'FAILED'
        )
    ),
    CONSTRAINT `fk_user_ban_effect_ban`
        FOREIGN KEY (`ban_id`) REFERENCES `user_bans` (`id`)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT `fk_user_ban_effect_identity_user`
        FOREIGN KEY (`identity_user_id`) REFERENCES `users` (`id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
