-- Global BraFurries integration, never a Community credential.
-- Secret ciphertext is AES-GCM with a versioned envelope; key remains outside DB.
CREATE TABLE platform_google_drive_connection (
    id TINYINT UNSIGNED NOT NULL,
    google_subject VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    google_email VARCHAR(255) NOT NULL,
    oauth_client_id VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    refresh_token_ciphertext VARBINARY(8192) NOT NULL,
    connected_by_user_id INT(11) NOT NULL,
    connected_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT ck_pgdc_singleton CHECK (id = 1),
    CONSTRAINT ck_pgdc_ciphertext CHECK (OCTET_LENGTH(refresh_token_ciphertext) >= 29),
    CONSTRAINT fk_pgdc_actor FOREIGN KEY (connected_by_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Single outstanding attempt per initiating owner. State is hashed;
-- PKCE verifier is encrypted, authorization code is never persisted.
CREATE TABLE platform_google_drive_oauth_attempt (
    owner_user_id INT(11) NOT NULL,
    state_hash BINARY(32) NOT NULL,
    verifier_ciphertext VARBINARY(1024) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (owner_user_id),
    UNIQUE KEY uq_pgdo_state (state_hash),
    KEY idx_pgdo_expiry (expires_at),
    CONSTRAINT ck_pgdo_expiry CHECK (expires_at > created_at),
    CONSTRAINT ck_pgdo_ciphertext CHECK (OCTET_LENGTH(verifier_ciphertext) >= 29),
    CONSTRAINT fk_pgdo_actor FOREIGN KEY (owner_user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Non-secret lifecycle evidence; never include token, code, state or verifier.
CREATE TABLE platform_google_drive_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    actor_user_id INT(11) NOT NULL,
    action VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_pgda_actor_time (actor_user_id, occurred_at),
    CONSTRAINT ck_pgda_action CHECK (action IN
        ('AUTHORIZATION_STARTED','CONNECTED','RECONNECTED','DISCONNECTED','AUTHORIZATION_FAILED')),
    CONSTRAINT fk_pgda_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
