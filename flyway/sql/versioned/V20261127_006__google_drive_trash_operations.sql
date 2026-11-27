-- One auditable operation per trash/restore lifecycle. Google owns retention.
CREATE TABLE platform_google_drive_trash_operations (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    anchor_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    parent_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(255) NOT NULL,
    expected_version VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    trashed_by_user_id INT(11) NOT NULL,
    restored_by_user_id INT(11) NULL,
    status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    active_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin
        GENERATED ALWAYS AS (CASE WHEN status IN ('TRASHING','TRASHED','RESTORING','RECONCILE_REQUIRED') THEN file_id ELSE NULL END) PERSISTENT,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    trashed_at DATETIME(6) NULL,
    restored_at DATETIME(6) NULL,
    PRIMARY KEY(id),
    UNIQUE KEY uq_pgdttrash_active(google_subject,active_file_id),
    KEY idx_pgdttrash_actor(trashed_by_user_id,created_at),
    KEY idx_pgdttrash_list(google_subject,root_folder_id,anchor_folder_id,status,id),
    CONSTRAINT fk_pgdttrash_actor FOREIGN KEY(trashed_by_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pgdttrash_restorer FOREIGN KEY(restored_by_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT ck_pgdttrash_status CHECK(status IN ('TRASHING','TRASHED','RESTORING','RESTORED','RECONCILE_REQUIRED','ABORTED','GONE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
