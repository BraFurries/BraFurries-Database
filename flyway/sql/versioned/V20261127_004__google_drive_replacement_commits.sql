-- Durable publication evidence; the staging upload remains a distinct resource.
CREATE TABLE platform_google_drive_replacement_commits (
    session_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    target_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    staged_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    staged_version VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    new_revision_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NULL,
    status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    active_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin
        GENERATED ALWAYS AS (CASE WHEN status IN ('APPLYING','RECONCILE_REQUIRED') THEN target_file_id ELSE NULL END) PERSISTENT,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY(session_id),
    UNIQUE KEY uq_pgdrcommit_active(google_subject,active_file_id),
    CONSTRAINT fk_pgdrcommit_intent FOREIGN KEY(session_id)
        REFERENCES platform_google_drive_replacement_intents(session_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_pgdrcommit_status CHECK(status IN ('APPLYING','APPLIED','RECONCILE_REQUIRED','ABORTED')),
    CONSTRAINT ck_pgdrcommit_checksum CHECK(staged_sha256 REGEXP '^[0-9a-f]{64}$'),
    CONSTRAINT ck_pgdrcommit_revision CHECK((status='APPLIED' AND new_revision_id IS NOT NULL)
        OR (status<>'APPLIED' AND new_revision_id IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
