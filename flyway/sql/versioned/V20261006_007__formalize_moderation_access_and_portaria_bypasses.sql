-- Formalize guild-scoped moderation/access and Portaria bypass configuration.
-- Database is the schema authority. Existing runtime-managed shapes remain only
-- as rollout bridges and are migrated into the canonical portaria_bypasses table.

ALTER TABLE `config_server_settings`
    ADD COLUMN IF NOT EXISTS `collab_moderation_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `collab_moderation_emoji` VARCHAR(64) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `collab_moderation_min_reactions` INT NOT NULL DEFAULT 3;

-- Formalize the current Portaria base shape. Existing values are preserved.
ALTER TABLE `portaria_base_config`
    ADD COLUMN IF NOT EXISTS `acesso_provisorio_role_id` BIGINT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `visitante_role_id` BIGINT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `maior_18_role_id` BIGINT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `menor_18_role_id` BIGINT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `aprovacao_acesso_provisorio_ativo` TINYINT(1) NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS `aprovacao_acesso_provisorio_duracao_dias` INT NOT NULL DEFAULT 15,
    ADD COLUMN IF NOT EXISTS `portaria_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS `idade_minima_conta_dias` INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `idade_minima_conta_ficha_ativa` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `idade_minima_conta_ficha_dias` INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `idade_minima_conta_acesso_provisorio_ativa` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `idade_minima_conta_acesso_provisorio_dias` INT NOT NULL DEFAULT 30,
    ADD COLUMN IF NOT EXISTS `idade_minima_entrada_servidor_ativa` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `idade_minima_entrada_servidor_anos` INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `invite_bypass_codes` TEXT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Invite provenance is required to enforce invite-based bypass against the
-- invite actually observed for this Community membership.
ALTER TABLE `user_community_status`
    ADD COLUMN IF NOT EXISTS `last_join_date` DATETIME NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `invite_link_used` VARCHAR(255) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `invited_by` VARCHAR(255) NULL DEFAULT NULL;

-- Legacy bridge used by the currently deployed runtime. Do not add new domain
-- behavior here; new writes belong to portaria_bypasses.
CREATE TABLE IF NOT EXISTS `portaria_account_release` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT NOT NULL,
    `user_id` BIGINT NOT NULL,
    `access_mode` VARCHAR(20) NOT NULL DEFAULT 'completo',
    `requires_form` TINYINT(1) NOT NULL DEFAULT 1,
    `released_by` BIGINT NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_portaria_account_release` (`server_guild_id`, `user_id`),
    KEY `idx_portaria_account_release_lookup` (`server_guild_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `portaria_account_release`
    ADD COLUMN IF NOT EXISTS `requires_form` TINYINT(1) NOT NULL DEFAULT 1;

-- Canonical model for every Portaria bypass.
CREATE TABLE IF NOT EXISTS `portaria_bypasses` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT NOT NULL,
    `bypass_type` VARCHAR(16) NOT NULL,
    `discord_user_id` BIGINT NULL DEFAULT NULL,
    `invite_code` VARCHAR(128) NULL DEFAULT NULL,
    `access_mode` VARCHAR(20) NULL DEFAULT NULL,
    `requires_form` TINYINT(1) NULL DEFAULT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `expires_at` DATETIME(6) NULL DEFAULT NULL,
    `expired_at` DATETIME(6) NULL DEFAULT NULL,
    `removed_at` DATETIME(6) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_portaria_bypass_account`
        (`server_guild_id`, `bypass_type`, `discord_user_id`),
    UNIQUE KEY `uq_portaria_bypass_invite`
        (`server_guild_id`, `bypass_type`, `invite_code`),
    KEY `idx_portaria_bypass_guild_active`
        (`server_guild_id`, `active`),
    KEY `idx_portaria_bypass_expiry`
        (`active`, `expires_at`),
    CONSTRAINT `ck_portaria_bypass_type`
        CHECK (`bypass_type` IN ('invite', 'account')),
    CONSTRAINT `ck_portaria_bypass_active`
        CHECK (`active` IN (0, 1)),
    CONSTRAINT `ck_portaria_bypass_target`
        CHECK (
            (
                `bypass_type` = 'account'
                AND `discord_user_id` IS NOT NULL
                AND `invite_code` IS NULL
                AND `access_mode` IN ('provisorio', 'completo')
                AND `requires_form` IN (0, 1)
            )
            OR
            (
                `bypass_type` = 'invite'
                AND `discord_user_id` IS NULL
                AND `invite_code` IS NOT NULL
                AND `access_mode` IS NULL
                AND `requires_form` IS NULL
            )
        )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Preserve existing account releases as canonical account bypasses.
INSERT IGNORE INTO `portaria_bypasses`
    (
        `server_guild_id`,
        `bypass_type`,
        `discord_user_id`,
        `access_mode`,
        `requires_form`,
        `active`,
        `created_at`,
        `updated_at`
    )
SELECT
    `server_guild_id`,
    'account',
    `user_id`,
    CASE
        WHEN LOWER(`access_mode`) = 'provisorio' THEN 'provisorio'
        ELSE 'completo'
    END,
    IF(`requires_form`, 1, 0),
    1,
    `created_at`,
    `updated_at`
FROM `portaria_account_release`;
