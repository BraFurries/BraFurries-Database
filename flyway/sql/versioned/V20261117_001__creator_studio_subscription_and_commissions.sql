-- Creator Studio belongs to users.id, independent of Community and commerce.
-- A subscription row is BOTH the invitation/authorization gate and the tier.
-- No automatic access, no seed grants and no payment handling in this migration.
-- Pilot members receive perpetual PRO entitlements, not a trial expiring later.
-- Migrate only from the Database repository after independent review.

CREATE TABLE creator_studio_subscriptions (
    user_id INT(11) NOT NULL,
    tier VARCHAR(8) NOT NULL,
    source_kind VARCHAR(12) NOT NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'ACTIVE',
    starts_at DATETIME(6) NOT NULL,
    -- NULL means lifetime access: allowed for FREE invitations and PILOT PRO.
    expires_at DATETIME(6) NULL,
    issued_by_user_id INT(11) NULL,
    external_reference VARCHAR(160) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (user_id),
    KEY idx_css_expiry (status, expires_at),
    KEY idx_css_issuer (issued_by_user_id),
    CONSTRAINT fk_css_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_css_issuer FOREIGN KEY (issued_by_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_css_tier CHECK (tier IN ('FREE', 'PRO')),
    CONSTRAINT ck_css_source CHECK (source_kind IN ('INVITE', 'PILOT', 'BILLING')),
    CONSTRAINT ck_css_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'REVOKED')),
    CONSTRAINT ck_css_window CHECK (expires_at IS NULL OR starts_at < expires_at),
    CONSTRAINT ck_css_origin CHECK (
        (source_kind='INVITE' AND tier='FREE'
            AND issued_by_user_id IS NOT NULL)
        OR (source_kind='PILOT' AND tier='PRO' AND expires_at IS NULL
            AND issued_by_user_id IS NOT NULL)
        OR (source_kind='BILLING' AND tier='PRO' AND expires_at IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Append-only grant/revocation/upgrade history, written atomically by API.
-- There is no "EXPIRED" event: expiry is computed from expires_at.
CREATE TABLE creator_studio_subscription_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id INT(11) NOT NULL,
    actor_user_id INT(11) NULL,
    action VARCHAR(24) NOT NULL,
    tier VARCHAR(8) NOT NULL,
    source_kind VARCHAR(12) NOT NULL,
    previous_status VARCHAR(12) NULL,
    new_status VARCHAR(12) NOT NULL,
    starts_at DATETIME(6) NOT NULL,
    expires_at DATETIME(6) NULL,
    occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_csse_user_time (user_id, occurred_at),
    KEY idx_csse_actor (actor_user_id),
    CONSTRAINT fk_csse_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csse_actor FOREIGN KEY (actor_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csse_action CHECK (
        action IN ('ACTIVATED', 'RENEWED', 'SUSPENDED', 'REVOKED', 'PLAN_CHANGED')
    ),
    CONSTRAINT ck_csse_tier CHECK (tier IN ('FREE', 'PRO')),
    CONSTRAINT ck_csse_source CHECK (
        source_kind IN ('INVITE', 'PILOT', 'BILLING')
    ),
    CONSTRAINT ck_csse_prev CHECK (
        previous_status IS NULL OR
        previous_status IN ('ACTIVE', 'SUSPENDED', 'REVOKED')
    ),
    CONSTRAINT ck_csse_new CHECK (
        new_status IN ('ACTIVE', 'SUSPENDED', 'REVOKED')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Reusable labels allow grouping by the same stage across different
-- workflows (e.g. Sketch for both icons and reference sheets).
CREATE TABLE creator_studio_stage_definitions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_cssd_owner_id (owner_user_id, id),
    UNIQUE KEY uq_cssd_owner_name (owner_user_id, name),
    CONSTRAINT fk_cssd_owner FOREIGN KEY (owner_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_cssd_name CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE creator_studio_workflows (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    name VARCHAR(100) NOT NULL,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    -- MariaDB UNIQUE admits multiple NULLs: at most one default per artist.
    default_owner_key INT(11) AS
        (CASE WHEN is_default = 1 THEN owner_user_id ELSE NULL END) PERSISTENT,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_csw_owner_id (owner_user_id, id),
    UNIQUE KEY uq_csw_owner_name (owner_user_id, name),
    UNIQUE KEY uq_csw_one_default (default_owner_key),
    CONSTRAINT fk_csw_owner FOREIGN KEY (owner_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csw_name CHECK (CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT ck_csw_default CHECK (is_default IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE creator_studio_workflow_steps (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    workflow_id BIGINT UNSIGNED NOT NULL,
    stage_definition_id BIGINT UNSIGNED NULL,
    name VARCHAR(100) NOT NULL,
    position SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_csws_position (workflow_id, position),
    KEY idx_csws_workflow_owner (owner_user_id, workflow_id),
    KEY idx_csws_stage (owner_user_id, stage_definition_id),
    CONSTRAINT fk_csws_workflow FOREIGN KEY (owner_user_id, workflow_id)
        REFERENCES creator_studio_workflows (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csws_stage FOREIGN KEY (owner_user_id, stage_definition_id)
        REFERENCES creator_studio_stage_definitions (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csws_name CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE creator_studio_art_types (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    name VARCHAR(100) NOT NULL,
    workflow_id BIGINT UNSIGNED NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_csat_owner_id (owner_user_id, id),
    UNIQUE KEY uq_csat_owner_name (owner_user_id, name),
    KEY idx_csat_workflow (owner_user_id, workflow_id),
    CONSTRAINT fk_csat_owner FOREIGN KEY (owner_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csat_workflow FOREIGN KEY (owner_user_id, workflow_id)
        REFERENCES creator_studio_workflows (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csat_name CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- All data is PRIVATE to owner_user_id. In particular, client_name and
-- description MUST NOT be exposed in public portfolio / Community endpoints.
CREATE TABLE creator_studio_commissions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    art_type_id BIGINT UNSIGNED NULL,
    title VARCHAR(160) NOT NULL,
    client_name VARCHAR(120) NOT NULL,
    description TEXT NULL,
    private_notes TEXT NULL,
    requested_on DATE NOT NULL,
    due_on DATE NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'QUEUED',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    completed_at DATETIME(6) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_csc_owner_id (owner_user_id, id),
    KEY idx_csc_queue (owner_user_id, status, requested_on, id),
    KEY idx_csc_requested (owner_user_id, requested_on, id),
    KEY idx_csc_art_type (owner_user_id, art_type_id),
    CONSTRAINT fk_csc_owner FOREIGN KEY (owner_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csc_art_type FOREIGN KEY (owner_user_id, art_type_id)
        REFERENCES creator_studio_art_types (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csc_title CHECK (CHAR_LENGTH(TRIM(title)) > 0),
    CONSTRAINT ck_csc_client CHECK (CHAR_LENGTH(TRIM(client_name)) > 0),
    CONSTRAINT ck_csc_status CHECK (
        status IN ('QUEUED', 'IN_PROGRESS', 'WAITING', 'PAUSED', 'COMPLETED')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Materialized steps: changing a workflow never changes existing commissions.
-- Shared stage_definition_id is OPTIONAL, purely for grouping across flows.
CREATE TABLE creator_studio_commission_steps (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    commission_id BIGINT UNSIGNED NOT NULL,
    stage_definition_id BIGINT UNSIGNED NULL,
    name VARCHAR(100) NOT NULL,
    position SMALLINT UNSIGNED NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    notes TEXT NULL,
    completed_at DATETIME(6) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_cscs_position (commission_id, position),
    KEY idx_cscs_owner_commission (owner_user_id, commission_id),
    KEY idx_cscs_stage (owner_user_id, stage_definition_id),
    CONSTRAINT fk_cscs_commission FOREIGN KEY (owner_user_id, commission_id)
        REFERENCES creator_studio_commissions (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_cscs_stage FOREIGN KEY (owner_user_id, stage_definition_id)
        REFERENCES creator_studio_stage_definitions (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_cscs_name CHECK (CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT ck_cscs_status CHECK (
        status IN ('PENDING', 'IN_PROGRESS', 'WAITING_APPROVAL', 'DONE')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Links/notes only in MVP. No uploaded files or R2 objects.
CREATE TABLE creator_studio_reference_links (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    commission_id BIGINT UNSIGNED NOT NULL,
    label VARCHAR(120) NULL,
    url VARCHAR(1500) NOT NULL,
    position SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_csrl_position (commission_id, position),
    KEY idx_csrl_owner_commission (owner_user_id, commission_id),
    CONSTRAINT fk_csrl_commission FOREIGN KEY (owner_user_id, commission_id)
        REFERENCES creator_studio_commissions (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csrl_url CHECK (CHAR_LENGTH(TRIM(url)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
