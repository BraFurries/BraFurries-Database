-- Temporary Discord Themes V1.
-- Theme is independent from structural Backup. No FK/column references backup_* tables.

CREATE TABLE IF NOT EXISTS discord_themes (
    id BIGINT NOT NULL AUTO_INCREMENT,
    guild_id BIGINT NOT NULL,
    name VARCHAR(120) NOT NULL,
    description VARCHAR(1000) NULL,
    icon_action VARCHAR(12) NOT NULL DEFAULT 'UNCHANGED',
    icon_asset_key VARCHAR(512) NULL,
    icon_asset_content_type VARCHAR(100) NULL,
    icon_asset_sha256 CHAR(64) NULL,
    icon_asset_size_bytes BIGINT NULL,
    banner_action VARCHAR(12) NOT NULL DEFAULT 'UNCHANGED',
    banner_asset_key VARCHAR(512) NULL,
    banner_asset_content_type VARCHAR(100) NULL,
    banner_asset_sha256 CHAR(64) NULL,
    banner_asset_size_bytes BIGINT NULL,
    created_by_discord_user_id BIGINT NOT NULL,
    created_by_user_id INT NULL,
    deleted_at DATETIME(6) NULL,
    active_name VARCHAR(120)
        AS (CASE WHEN deleted_at IS NULL THEN name ELSE NULL END) STORED,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_discord_themes_guild_active_name (guild_id, active_name),
    UNIQUE KEY uq_discord_themes_guild_id (guild_id, id),
    KEY idx_discord_themes_guild_deleted (guild_id, deleted_at, id),
    CONSTRAINT fk_discord_themes_created_by_user
        FOREIGN KEY (created_by_user_id) REFERENCES users(id)
        ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_discord_themes_icon_action
        CHECK (icon_action IN ('UNCHANGED', 'SET', 'REMOVE')),
    CONSTRAINT ck_discord_themes_banner_action
        CHECK (banner_action IN ('UNCHANGED', 'SET', 'REMOVE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_assets (
    id BIGINT NOT NULL AUTO_INCREMENT,
    theme_id BIGINT NOT NULL,
    guild_id BIGINT NOT NULL,
    asset_type VARCHAR(12) NOT NULL,
    storage_key VARCHAR(512) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    sha256 CHAR(64) NOT NULL,
    size_bytes BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_discord_theme_asset_key (storage_key),
    KEY idx_discord_theme_assets_theme (theme_id,asset_type,id),
    KEY idx_discord_theme_assets_guild (guild_id,theme_id,id),
    CONSTRAINT fk_discord_theme_asset_theme
        FOREIGN KEY (guild_id,theme_id) REFERENCES discord_themes(guild_id,id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_discord_theme_asset_type
        CHECK (asset_type IN ('ICON', 'BANNER')),
    CONSTRAINT ck_discord_theme_asset_size
        CHECK (size_bytes > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_resource_changes (
    id BIGINT NOT NULL AUTO_INCREMENT,
    theme_id BIGINT NOT NULL,
    resource_type VARCHAR(16) NOT NULL,
    resource_discord_id BIGINT NOT NULL,
    target_name VARCHAR(100) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_discord_theme_resource (theme_id, resource_type, resource_discord_id),
    KEY idx_discord_theme_resource_theme (theme_id, id),
    CONSTRAINT fk_discord_theme_resource_theme
        FOREIGN KEY (theme_id) REFERENCES discord_themes(id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_discord_theme_resource_type
        CHECK (resource_type IN ('CHANNEL', 'CATEGORY', 'ROLE')),
    CONSTRAINT ck_discord_theme_resource_id
        CHECK (resource_discord_id > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_applications (
    id BIGINT NOT NULL AUTO_INCREMENT,
    theme_id BIGINT NOT NULL,
    guild_id BIGINT NOT NULL,
    actor_discord_user_id BIGINT NOT NULL,
    actor_user_id INT NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'APPLYING',
    frozen_definition_json LONGTEXT NOT NULL,
    applied_at DATETIME(6) NULL,
    restored_at DATETIME(6) NULL,
    error_summary VARCHAR(512) NULL,
    rollback_assets_cleaned_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_discord_theme_app_guild_id (guild_id,id),
    KEY idx_discord_theme_app_guild_status (guild_id, status, id),
    KEY idx_discord_theme_app_theme (theme_id, id),
    CONSTRAINT fk_discord_theme_app_theme
        FOREIGN KEY (guild_id,theme_id) REFERENCES discord_themes(guild_id,id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_discord_theme_app_actor_user
        FOREIGN KEY (actor_user_id) REFERENCES users(id)
        ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_discord_theme_app_status
        CHECK (status IN (
            'APPLYING', 'ACTIVE', 'APPLY_PARTIAL', 'FAILED',
            'RESTORING', 'RESTORED', 'RESTORE_PARTIAL'
        ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_application_snapshots (
    id BIGINT NOT NULL AUTO_INCREMENT,
    application_id BIGINT NOT NULL,
    resource_type VARCHAR(20) NOT NULL,
    resource_discord_id BIGINT NOT NULL DEFAULT 0,
    before_value VARCHAR(255) NULL,
    applied_value VARCHAR(255) NULL,
    before_asset_key VARCHAR(512) NULL,
    before_asset_content_type VARCHAR(100) NULL,
    before_asset_sha256 CHAR(64) NULL,
    applied_asset_key VARCHAR(512) NULL,
    applied_asset_content_type VARCHAR(100) NULL,
    applied_asset_sha256 CHAR(64) NULL,
    apply_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    restore_status VARCHAR(20) NULL,
    error_code VARCHAR(96) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_discord_theme_snapshot_resource
        (application_id, resource_type, resource_discord_id),
    KEY idx_discord_theme_snapshot_application (application_id, id),
    CONSTRAINT fk_discord_theme_snapshot_application
        FOREIGN KEY (application_id) REFERENCES discord_theme_applications(id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_discord_theme_snapshot_type
        CHECK (resource_type IN ('GUILD_ICON', 'GUILD_BANNER', 'CHANNEL', 'CATEGORY', 'ROLE')),
    CONSTRAINT ck_discord_theme_snapshot_apply_status
        CHECK (apply_status IN ('PENDING', 'APPLIED', 'SKIPPED', 'FAILED')),
    CONSTRAINT ck_discord_theme_snapshot_restore_status
        CHECK (restore_status IS NULL OR restore_status IN ('RESTORED', 'DRIFTED', 'MISSING', 'SKIPPED', 'FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_operations (
    id BIGINT NOT NULL AUTO_INCREMENT,
    application_id BIGINT NOT NULL,
    guild_id BIGINT NOT NULL,
    operation_key VARCHAR(96) NOT NULL,
    operation_type VARCHAR(12) NOT NULL,
    actor_discord_user_id BIGINT NOT NULL,
    actor_user_id INT NULL,
    force_restore TINYINT(1) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    progress_current INT NOT NULL DEFAULT 0,
    progress_total INT NOT NULL DEFAULT 0,
    current_step VARCHAR(96) NULL,
    result_json LONGTEXT NULL,
    error_code VARCHAR(96) NULL,
    requested_audited_at DATETIME(6) NULL,
    completion_audited_at DATETIME(6) NULL,
    started_at DATETIME(6) NULL,
    finished_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_discord_theme_operation_key (guild_id, operation_key),
    UNIQUE KEY uq_discord_theme_operation_guild_id (guild_id,id),
    UNIQUE KEY uq_discord_theme_operation_guild_id_app (guild_id,id,application_id),
    KEY idx_discord_theme_operation_app (application_id, operation_type, id),
    KEY idx_discord_theme_operation_guild_status (guild_id, status, id),
    CONSTRAINT fk_discord_theme_operation_application
        FOREIGN KEY (guild_id,application_id)
        REFERENCES discord_theme_applications(guild_id,id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_discord_theme_operation_actor_user
        FOREIGN KEY (actor_user_id) REFERENCES users(id)
        ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_discord_theme_operation_type
        CHECK (operation_type IN ('APPLY', 'RESTORE')),
    CONSTRAINT ck_discord_theme_operation_status
        CHECK (status IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'PARTIAL', 'FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_operation_steps (
    id BIGINT NOT NULL AUTO_INCREMENT,
    operation_id BIGINT NOT NULL,
    guild_id BIGINT NOT NULL,
    step_code VARCHAR(96) NOT NULL,
    step_status VARCHAR(20) NOT NULL,
    message VARCHAR(512) NOT NULL,
    progress_current INT NOT NULL DEFAULT 0,
    progress_total INT NOT NULL DEFAULT 0,
    detail_json LONGTEXT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_discord_theme_operation_steps (operation_id, id),
    KEY idx_discord_theme_operation_steps_guild (guild_id, operation_id, id),
    CONSTRAINT fk_discord_theme_operation_step_operation
        FOREIGN KEY (guild_id,operation_id)
        REFERENCES discord_theme_operations(guild_id,id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_discord_theme_operation_step_status
        CHECK (step_status IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'SKIPPED', 'FAILED', 'DRIFTED', 'MISSING'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_active_guilds (
    guild_id BIGINT NOT NULL,
    application_id BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (guild_id),
    UNIQUE KEY uq_discord_theme_active_application (application_id),
    CONSTRAINT fk_discord_theme_active_application
        FOREIGN KEY (guild_id,application_id)
        REFERENCES discord_theme_applications(guild_id,id)
        ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS discord_theme_guild_locks (
    guild_id BIGINT NOT NULL,
    lock_token VARCHAR(96) NOT NULL,
    operation_type VARCHAR(12) NOT NULL,
    operation_id BIGINT NOT NULL,
    application_id BIGINT NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (guild_id),
    KEY idx_discord_theme_lock_expiry (expires_at),
    CONSTRAINT fk_discord_theme_lock_operation
        FOREIGN KEY (guild_id,operation_id,application_id)
        REFERENCES discord_theme_operations(guild_id,id,application_id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_discord_theme_lock_operation
        CHECK (operation_type IN ('APPLY', 'RESTORE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
