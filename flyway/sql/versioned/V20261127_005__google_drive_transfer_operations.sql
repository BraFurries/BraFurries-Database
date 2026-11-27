-- Move/copy operations have durable identity before any provider write.
CREATE TABLE platform_google_drive_transfer_operations (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    actor_user_id INT(11) NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    source_anchor_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    source_parent_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    source_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    destination_anchor_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    destination_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    result_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expected_version VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    operation VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    active_file_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin
        GENERATED ALWAYS AS (CASE WHEN status IN ('PENDING','RECONCILE_REQUIRED') THEN source_file_id ELSE NULL END) PERSISTENT,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY(id),
    UNIQUE KEY uq_pgdt_active(google_subject,active_file_id),
    KEY idx_pgdt_result(google_subject,operation,status,result_file_id),
    KEY idx_pgdt_actor(actor_user_id,created_at),
    CONSTRAINT fk_pgdt_actor FOREIGN KEY(actor_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT ck_pgdt_operation CHECK(operation IN ('MOVE','COPY')),
    CONSTRAINT ck_pgdt_status CHECK(status IN ('PENDING','COMPLETED','RECONCILE_REQUIRED','ABORTED')),
    CONSTRAINT ck_pgdt_result CHECK((operation='MOVE' AND source_file_id=result_file_id) OR
        (operation='COPY' AND source_file_id<>result_file_id))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
