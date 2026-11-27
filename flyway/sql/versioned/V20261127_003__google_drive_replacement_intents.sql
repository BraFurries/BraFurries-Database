-- Replacement uses a NEW staging file, never a browser capability targeting
-- the original. Link the intent atomically to the existing upload reservation.
CREATE TABLE platform_google_drive_replacement_intents (
    session_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    target_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expected_version VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    previous_revision_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    previous_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    previous_name VARCHAR(255) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY(session_id),
    KEY idx_pgdr_target(google_subject,target_file_id,created_at),
    CONSTRAINT fk_pgdr_session FOREIGN KEY(session_id)
        REFERENCES platform_google_drive_upload_sessions(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_pgdr_version CHECK(expected_version REGEXP '^[0-9]{1,32}$'),
    CONSTRAINT ck_pgdr_checksum CHECK(previous_sha256 REGEXP '^[0-9a-f]{64}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
