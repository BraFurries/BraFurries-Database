-- BraFurries partner catalog integration with Discord.
-- Control-plane state belongs to API; Coddy only executes Discord effects.
-- Empty additive tables: existing partners, guilds and channels are untouched.
-- API must allow writes only for the configured official BraFurries Community.
-- Discord snowflakes are BIGINT external references, never internal PKs.
--
-- Rollout: Database -> Coddy runtime -> API -> Front. No external resource is
-- created or modified by this migration. All publication is opt-in until configured.

CREATE TABLE partner_discord_config (
    community_id INT(11) NOT NULL,
    guild_id BIGINT(20) NOT NULL,
    category_id BIGINT(20) NULL,
    category_created_by_bot TINYINT(1) NOT NULL DEFAULT 0,
    thread_parent_channel_id BIGINT(20) NULL,
    thread_parent_created_by_bot TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (community_id),
    UNIQUE KEY uq_partner_discord_guild (guild_id),
    CONSTRAINT ck_pdc_parent_category CHECK
        (thread_parent_channel_id IS NULL OR category_id IS NOT NULL),
    CONSTRAINT fk_pdc_community FOREIGN KEY (community_id)
        REFERENCES communities (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_pdc_category_origin CHECK
        (category_created_by_bot IN (0,1)
         AND (category_created_by_bot = 0 OR category_id IS NOT NULL)),
    CONSTRAINT ck_pdc_thread_origin CHECK
        (thread_parent_created_by_bot IN (0,1)
         AND (thread_parent_created_by_bot = 0 OR thread_parent_channel_id IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Partner's desired Discord state and last applied resource IDs.
-- An explicit existing_text_channel_id is an adoption request, not permission
-- to overwrite its ACL; Coddy must preview/validate ownership first.
-- Existing resources must never be deleted automatically on partner deletion.
-- RESTRICT ensures manual deprovisioning before deleting a published partner.
CREATE TABLE partner_discord_publications (
    partner_id INT(11) NOT NULL,
    community_id INT(11) NOT NULL,
    exclusive_channel_enabled TINYINT(1) NOT NULL DEFAULT 0,
    existing_text_channel_id BIGINT(20) NULL,
    adopt_existing_text_channel TINYINT(1) NOT NULL DEFAULT 0,
    representative_discord_user_id BIGINT(20) NULL,
    thread_id BIGINT(20) NULL,
    thread_intro_message_id BIGINT(20) NULL,
    text_channel_id BIGINT(20) NULL,
    text_intro_message_id BIGINT(20) NULL,
    text_channel_created_by_bot TINYINT(1) NOT NULL DEFAULT 0,
    desired_revision BIGINT(20) NOT NULL DEFAULT 1,
    applied_revision BIGINT(20) NOT NULL DEFAULT 0,
    last_synced_at DATETIME(6) NULL,
    last_sync_error VARCHAR(512) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (partner_id),
    KEY idx_pdp_community_revision (community_id, desired_revision, applied_revision),
    UNIQUE KEY uq_pdp_thread (thread_id),
    UNIQUE KEY uq_pdp_text_channel (text_channel_id),
    UNIQUE KEY uq_pdp_existing_text_channel (existing_text_channel_id),
    CONSTRAINT fk_pdp_partner FOREIGN KEY (partner_id)
        REFERENCES partners (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pdp_config FOREIGN KEY (community_id)
        REFERENCES partner_discord_config (community_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_pdp_exclusive CHECK (exclusive_channel_enabled IN (0,1) AND adopt_existing_text_channel IN (0,1)),
    CONSTRAINT ck_pdp_managed CHECK (text_channel_created_by_bot IN (0,1)),
    CONSTRAINT ck_pdp_revisions CHECK
        (desired_revision >= 1 AND applied_revision >= 0
         AND applied_revision <= desired_revision)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- A small append-only audit records who requested configuration, channel
-- adoption and publication. Do not persist private tokens or message contents.
CREATE TABLE partner_discord_audit (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    community_id INT(11) NOT NULL,
    partner_id INT(11) NULL,
    actor_user_id INT(11) NOT NULL,
    action VARCHAR(40) NOT NULL,
    details VARCHAR(512) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_pda_partner_created (partner_id, created_at),
    KEY idx_pda_community_created (community_id, created_at),
    CONSTRAINT fk_pda_community FOREIGN KEY (community_id)
        REFERENCES communities (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pda_partner FOREIGN KEY (partner_id)
        REFERENCES partners (id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_pda_actor FOREIGN KEY (actor_user_id)
        REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_pda_action CHECK (action IN (
        'CONFIG_UPDATED', 'PARTNER_OPTION_UPDATED', 'SYNC_REQUESTED',
        'SYNC_SUCCEEDED', 'SYNC_FAILED', 'POST_PUBLISHED',
        'UNPUBLISHED'
    ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
