-- Durable, per-Community role tools control-plane state. Discord side effects live
-- exclusively in Coddy. Audit records are retained across bot restarts.
-- Never use this table for global record blacklist policy.
CREATE TABLE guild_role_tool_operations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    community_id INT(11) NOT NULL,
    guild_id BIGINT(20) NOT NULL,
    operation_key VARCHAR(96) NOT NULL,
    operation_type VARCHAR(24) NOT NULL,
    actor_user_id INT(11) NOT NULL,
    actor_discord_user_id BIGINT(20) NOT NULL,
    source_operation_id BIGINT UNSIGNED NULL,
    source_bot VARCHAR(16) NULL,
    channel_id BIGINT(20) NULL,
    role_id BIGINT(20) NULL,
    role_key VARCHAR(200) NULL,
    preview_fingerprint CHAR(64) NULL,
    expected_count INT UNSIGNED NOT NULL DEFAULT 0,
    progress_current INT UNSIGNED NOT NULL DEFAULT 0,
    progress_total INT UNSIGNED NOT NULL DEFAULT 0,
    added_count INT UNSIGNED NOT NULL DEFAULT 0,
    skipped_count INT UNSIGNED NOT NULL DEFAULT 0,
    failed_count INT UNSIGNED NOT NULL DEFAULT 0,
    scanned_count INT UNSIGNED NOT NULL DEFAULT 0,
    result_json LONGTEXT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    error_code VARCHAR(96) NULL,
    started_at DATETIME(6) NULL,
    finished_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    active_guild_id BIGINT(20) AS (
        CASE WHEN status IN ('PENDING','RUNNING') THEN guild_id ELSE NULL END
    ) PERSISTENT,
    PRIMARY KEY (id),
    UNIQUE KEY uq_grto_guild_operation_key (guild_id, operation_key),
    UNIQUE KEY uq_grto_active_guild (active_guild_id),
    KEY idx_grto_community_recent (community_id, created_at),
    KEY idx_grto_guild_recent (guild_id, id),
    KEY idx_grto_source (source_operation_id),
    CONSTRAINT fk_grto_community FOREIGN KEY (community_id)
        REFERENCES communities(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_grto_guild FOREIGN KEY (guild_id)
        REFERENCES community_discord(guild_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_grto_actor FOREIGN KEY (actor_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_grto_source FOREIGN KEY (source_operation_id)
        REFERENCES guild_role_tool_operations(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_grto_type CHECK (
        operation_type IN ('BULK_ADD','RECOVERY_SCAN','RECOVERY_APPLY')
    ),
    CONSTRAINT ck_grto_status CHECK (
        status IN ('PENDING','RUNNING','READY','SUCCEEDED','PARTIAL','FAILED','CANCELLED')
    ),
    CONSTRAINT ck_grto_fingerprint CHECK (
        preview_fingerprint IS NULL OR CHAR_LENGTH(preview_fingerprint)=64
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE guild_role_tool_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    operation_id BIGINT UNSIGNED NOT NULL,
    community_id INT(11) NOT NULL,
    guild_id BIGINT(20) NOT NULL,
    actor_user_id INT(11) NULL,
    event_type VARCHAR(24) NOT NULL,
    detail VARCHAR(512) NULL,
    occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_grta_community_time (community_id, occurred_at),
    KEY idx_grta_guild_time (guild_id, occurred_at),
    KEY idx_grta_operation (operation_id, id),
    CONSTRAINT fk_grta_operation FOREIGN KEY (operation_id)
        REFERENCES guild_role_tool_operations(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_grta_community FOREIGN KEY (community_id)
        REFERENCES communities(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_grta_actor FOREIGN KEY (actor_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
