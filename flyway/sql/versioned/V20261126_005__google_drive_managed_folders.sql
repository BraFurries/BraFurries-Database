-- Global institutional registry, not a Community resource.
-- No grants or Google ACL mutations are introduced by this migration.
-- Bind every mapping to the verified Google subject and configured root.
CREATE TABLE platform_google_drive_managed_folders (
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    parent_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    folder_name VARCHAR(255) NOT NULL,
    registered_by_user_id INT(11) NOT NULL,
    registered_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    verified_by_user_id INT(11) NOT NULL,
    verified_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (google_subject, root_folder_id, folder_id),
    CONSTRAINT ck_pgd_folder_not_root CHECK (folder_id <> root_folder_id),
    CONSTRAINT ck_pgd_folder_not_self CHECK (folder_id <> parent_folder_id),
    CONSTRAINT fk_pgdm_registered_actor FOREIGN KEY (registered_by_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_pgdm_verified_actor FOREIGN KEY (verified_by_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
