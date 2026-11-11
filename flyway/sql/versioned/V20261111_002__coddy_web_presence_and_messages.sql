-- Global Coddy identity management and privileged Web-origin Discord sends.
-- Only the API owns desired presence, authorization, idempotency and the audit;
-- Coddy reads desired presence and executes Discord effects.
-- No historical guild/message data is changed. Discord snowflakes are BIGINT.
-- Rollout: Database -> Coddy internal endpoints -> API -> Front -> retire slash commands.
-- Never expose these controls to tenant administrators solely by guild ownership.

CREATE TABLE coddy_presence_settings (
    singleton_id TINYINT UNSIGNED NOT NULL,
    activity_type VARCHAR(16) NOT NULL,
    activity_text VARCHAR(128) NOT NULL,
    availability VARCHAR(16) NOT NULL DEFAULT 'online',
    revision BIGINT UNSIGNED NOT NULL DEFAULT 1,
    updated_by_user_id INT(11) NOT NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (singleton_id),
    CONSTRAINT ck_cps_singleton CHECK (singleton_id = 1),
    CONSTRAINT ck_cps_activity CHECK (activity_type IN ('PLAYING', 'LISTENING', 'WATCHING', 'CUSTOM')),
    CONSTRAINT ck_cps_availability CHECK (availability IN ('online', 'idle', 'dnd', 'invisible')),
    CONSTRAINT ck_cps_revision CHECK (revision > 0),
    CONSTRAINT fk_coddy_presence_updated_by_user FOREIGN KEY (updated_by_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Every requested outbound message has a unique request key. A timeout after
-- posting to Discord MUST NOT cause an automatic replay; REQUESTED/UNKNOWN
-- remains unresolved until explicitly reconciled by a human operator.
-- Store a digest, never the message body or bot credentials.
CREATE TABLE coddy_admin_action_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    request_key CHAR(36) NOT NULL,
    action_type VARCHAR(20) NOT NULL,
    actor_user_id INT(11) NOT NULL,
    community_id INT(11) NULL,
    guild_id BIGINT(20) NULL,
    channel_id BIGINT(20) NULL,
    payload_sha256 CHAR(64) NULL,
    outcome VARCHAR(20) NOT NULL DEFAULT 'REQUESTED',
    discord_message_id BIGINT(20) NULL,
    error_code VARCHAR(64) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_caa_request_key (request_key),
    KEY idx_caa_actor_time (actor_user_id, created_at),
    KEY idx_caa_community_time (community_id, created_at),
    CONSTRAINT fk_coddy_admin_action_actor_user FOREIGN KEY (actor_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_coddy_admin_action_community FOREIGN KEY (community_id)
        REFERENCES communities(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_caa_action_type CHECK (action_type IN ('PRESENCE_UPDATE', 'MESSAGE_SEND')),
    CONSTRAINT ck_caa_outcome CHECK (outcome IN ('REQUESTED', 'APPLIED', 'SENT', 'FAILED', 'UNKNOWN')),
    CONSTRAINT ck_caa_message_scope CHECK (
        (action_type = 'PRESENCE_UPDATE' AND community_id IS NULL AND guild_id IS NULL AND channel_id IS NULL)
        OR (action_type = 'MESSAGE_SEND' AND community_id IS NOT NULL AND guild_id IS NOT NULL AND channel_id IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
