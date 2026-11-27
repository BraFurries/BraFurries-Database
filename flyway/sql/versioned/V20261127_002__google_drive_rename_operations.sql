-- Metadata-only changes. Uncertain operations block another rename of the
-- same Google resource until explicitly reconciled. No provider token stored.
CREATE TABLE platform_google_drive_rename_operations (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    actor_user_id INT(11) NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    anchor_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    parent_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expected_version VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    old_name VARCHAR(255) NOT NULL,
    new_name VARCHAR(255) NOT NULL,
    status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    active_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin
        GENERATED ALWAYS AS (CASE WHEN status IN ('PENDING','RECONCILE_REQUIRED') THEN file_id ELSE NULL END) PERSISTENT,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY(id),
    UNIQUE KEY uq_pgdrename_active(google_subject,active_file_id),
    KEY idx_pgdrename_actor(actor_user_id,created_at),
    CONSTRAINT fk_pgdrename_actor FOREIGN KEY(actor_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT ck_pgdrename_status CHECK(status IN ('PENDING','RENAMED','RECONCILE_REQUIRED','ABORTED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
