-- Creator Studio: auditable reminder delivery and exceptional retention holds.
-- No emails, grants, DELETE or production data updates are performed by Flyway.
-- Works only after the Creator Studio foundation + activity/retention migrations.

CREATE TABLE creator_studio_retention_notices (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    commission_id BIGINT UNSIGNED NOT NULL,
    completed_at DATETIME(6) NOT NULL,
    notice_kind VARCHAR(4) NOT NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'PENDING',
    attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    claimed_at DATETIME(6) NULL,
    sent_at DATETIME(6) NULL,
    last_error_code VARCHAR(32) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_csrn_epoch (owner_user_id,commission_id,completed_at,notice_kind),
    KEY idx_csrn_queue (status,created_at,id),
    KEY idx_csrn_commission (owner_user_id,commission_id),
    CONSTRAINT fk_csrn_commission FOREIGN KEY (owner_user_id,commission_id)
        REFERENCES creator_studio_commissions (owner_user_id,id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csrn_kind CHECK (notice_kind IN ('D30','D7')),
    CONSTRAINT ck_csrn_status CHECK (
        status IN ('PENDING','SENDING','SENT','UNKNOWN')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Holds are set/released ONLY by the platform owner; the cleanup worker must
-- recheck this row under a lock before deleting a commission.
CREATE TABLE creator_studio_retention_holds (
    owner_user_id INT(11) NOT NULL,
    commission_id BIGINT UNSIGNED NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    category VARCHAR(20) NOT NULL,
    reason VARCHAR(500) NOT NULL,
    created_by_user_id INT(11) NOT NULL,
    updated_by_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (owner_user_id,commission_id),
    KEY idx_csrh_active (active,owner_user_id,commission_id),
    CONSTRAINT fk_csrh_commission FOREIGN KEY (owner_user_id,commission_id)
        REFERENCES creator_studio_commissions (owner_user_id,id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csrh_creator FOREIGN KEY (created_by_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csrh_editor FOREIGN KEY (updated_by_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csrh_active CHECK (active IN (0,1)),
    CONSTRAINT ck_csrh_category CHECK (
        category IN ('LEGAL_OBLIGATION','DISPUTE','DATA_REQUEST','OTHER')
    ),
    CONSTRAINT ck_csrh_reason CHECK (
        CHAR_LENGTH(TRIM(reason)) > 0 AND CHAR_LENGTH(reason) <= 500
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Minimal immutable audit: no customer names, references, personal notes or
-- hold reason. Deliberately no commission FK so the audit may outlive purges.
CREATE TABLE creator_studio_retention_hold_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    commission_id BIGINT UNSIGNED NOT NULL,
    actor_user_id INT(11) NOT NULL,
    action VARCHAR(12) NOT NULL,
    category VARCHAR(20) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_csrhe_commission (owner_user_id,commission_id,id),
    CONSTRAINT fk_csrhe_owner FOREIGN KEY (owner_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csrhe_actor FOREIGN KEY (actor_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csrhe_action CHECK (action IN ('PLACED','RELEASED')),
    CONSTRAINT ck_csrhe_category CHECK (
        category IN ('LEGAL_OBLIGATION','DISPUTE','DATA_REQUEST','OTHER')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
