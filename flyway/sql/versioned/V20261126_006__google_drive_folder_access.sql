-- Explicit folder ACLs, distinct from provider ACLs. No default grants.
-- Effective access is intersection of personal ceiling and active official Team role grants.
-- Revoking platform approval cascades personal folder grants. No external access is applied here.
CREATE TABLE platform_google_drive_person_grants (
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id INT(11) NOT NULL,
    permission_code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    granted_by_user_id INT(11) NOT NULL,
    granted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (google_subject,root_folder_id,folder_id,user_id,permission_code),
    CONSTRAINT ck_pgd_person_code CHECK (permission_code IN ('VIEW','DOWNLOAD','UPLOAD','CREATE_FOLDER','RENAME','REPLACE','MOVE','TRASH','EXTERNAL_VIEW','EXTERNAL_EDIT','EXTERNAL_FOLDER')),
    CONSTRAINT fk_pgd_person_folder FOREIGN KEY (google_subject,root_folder_id,folder_id)
        REFERENCES platform_google_drive_managed_folders(google_subject,root_folder_id,folder_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_pgd_person_principal FOREIGN KEY (user_id) REFERENCES platform_authorized_users(user_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_pgd_person_actor FOREIGN KEY (granted_by_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE platform_google_drive_role_grants (
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    role_id INT(11) NOT NULL,
    permission_code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    granted_by_user_id INT(11) NOT NULL,
    granted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (google_subject,root_folder_id,folder_id,role_id,permission_code),
    CONSTRAINT ck_pgd_role_code CHECK (permission_code IN ('VIEW','DOWNLOAD','UPLOAD','CREATE_FOLDER','RENAME','REPLACE','MOVE','TRASH','EXTERNAL_VIEW','EXTERNAL_EDIT','EXTERNAL_FOLDER')),
    CONSTRAINT fk_pgd_role_folder FOREIGN KEY (google_subject,root_folder_id,folder_id)
        REFERENCES platform_google_drive_managed_folders(google_subject,root_folder_id,folder_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_pgd_role_principal FOREIGN KEY (role_id) REFERENCES community_team_roles(id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_pgd_role_actor FOREIGN KEY (granted_by_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE platform_google_drive_folder_access_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    folder_id VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    actor_user_id INT(11) NOT NULL,
    principal_type VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    principal_id INT(11) NOT NULL,
    permission_code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    action VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_pgdfaa_folder (google_subject,root_folder_id,folder_id,id),
    CONSTRAINT ck_pgdfaa_principal CHECK (principal_type IN ('PERSON','ROLE')),
    CONSTRAINT ck_pgdfaa_code CHECK (permission_code IN ('VIEW','DOWNLOAD','UPLOAD','CREATE_FOLDER','RENAME','REPLACE','MOVE','TRASH','EXTERNAL_VIEW','EXTERNAL_EDIT','EXTERNAL_FOLDER')),
    CONSTRAINT ck_pgdfaa_action CHECK (action IN ('GRANT','REVOKE')),
    CONSTRAINT fk_pgdfaa_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
