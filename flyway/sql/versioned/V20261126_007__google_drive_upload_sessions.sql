-- Direct resumable uploads: local lifecycle and provider identity, not file bytes.
-- No session URL is persisted by this version. A lost browser session must be
-- reconciled by its preallocated Google file ID, not by a client-supplied ID.
CREATE TABLE platform_google_drive_upload_sessions (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    anchor_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    destination_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    staging_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    actor_user_id INT(11) NOT NULL,
    provider_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expected_size BIGINT UNSIGNED NOT NULL,
    status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    next_reconcile_at DATETIME(6) NULL,
    published_at DATETIME(6) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_pgdu_provider (google_subject,provider_file_id),
    KEY idx_pgdu_actor_status (actor_user_id,status,expires_at),
    KEY idx_pgdu_reconcile (next_reconcile_at,status),
    KEY idx_pgdu_scope (google_subject,root_folder_id,created_at),
    CONSTRAINT fk_pgdu_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_pgdu_status CHECK (status IN ('RESERVED','OPEN','PUBLISHING','PUBLISHED',
        'CANCELED','EXPIRED','CLEANUP_PENDING','CLEANED','RECONCILE_REQUIRED')),
    CONSTRAINT ck_pgdu_expiry CHECK (expires_at>created_at),
    CONSTRAINT ck_pgdu_size CHECK (expected_size>0),
    CONSTRAINT ck_pgdu_staging CHECK (staging_folder_id<>root_folder_id
        AND staging_folder_id<>anchor_folder_id AND staging_folder_id<>destination_folder_id),
    CONSTRAINT ck_pgdu_published CHECK ((status='PUBLISHED' AND published_at IS NOT NULL)
        OR (status<>'PUBLISHED' AND published_at IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE platform_google_drive_upload_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    session_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    actor_user_id INT(11) NULL,
    action VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_pgdua_session (session_id,id),
    CONSTRAINT fk_pgdua_session FOREIGN KEY (session_id)
        REFERENCES platform_google_drive_upload_sessions(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_pgdua_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_pgdua_action CHECK (action IN ('RESERVED','OPENED','PUBLISH_STARTED',
        'PUBLISHED','CANCELED','EXPIRED','CLEANUP_PENDING','CLEANED','RECONCILE_REQUIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
