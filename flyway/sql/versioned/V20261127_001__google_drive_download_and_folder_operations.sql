-- Single-use native download capabilities. Store only SHA-256, never the bearer.
CREATE TABLE platform_google_drive_download_tickets (
    ticket_hash BINARY(32) NOT NULL,
    actor_user_id INT(11) NOT NULL,
    auth_version BIGINT NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    anchor_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at DATETIME(6) NOT NULL,
    consumed_at DATETIME(6) NULL,
    PRIMARY KEY(ticket_hash),
    KEY idx_pgddt_actor(actor_user_id,created_at),
    KEY idx_pgddt_expiry(expires_at),
    CONSTRAINT fk_pgddt_actor FOREIGN KEY(actor_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT ck_pgddt_expiry CHECK(expires_at>created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE platform_google_drive_folder_operations (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    actor_user_id INT(11) NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    anchor_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    parent_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    provider_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    folder_name VARCHAR(255) NOT NULL,
    status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY(id),
    UNIQUE KEY uq_pgdfo_provider(google_subject,provider_folder_id),
    KEY idx_pgdfo_scope(google_subject,status),
    KEY idx_pgdfo_actor(actor_user_id,created_at),
    CONSTRAINT fk_pgdfo_actor FOREIGN KEY(actor_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT ck_pgdfo_status CHECK(status IN ('PENDING','CREATED','RECONCILE_REQUIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
