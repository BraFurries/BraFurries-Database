-- Creator Studio V1: artist-reported private commission timeline.
-- No authenticated client approval is inferred from this table.
-- The artist owns the record; Community is deliberately NOT a tenant here.
-- Reference links already live in creator_studio_reference_links (V20261117_001).

CREATE TABLE creator_studio_activity (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id INT(11) NOT NULL,
    commission_id BIGINT UNSIGNED NOT NULL,
    event_kind VARCHAR(24) NOT NULL,
    description TEXT NOT NULL,
    occurred_on DATE NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_csa_order (owner_user_id, commission_id, occurred_on, id),
    CONSTRAINT fk_csa_commission FOREIGN KEY (owner_user_id, commission_id)
        REFERENCES creator_studio_commissions (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csa_kind CHECK (event_kind IN (
        'NOTE', 'REVISION_REQUEST', 'CHANGE_RECORDED',
        'CLIENT_FEEDBACK', 'APPROVAL_REPORTED', 'DELIVERY_RECORDED'
    )),
    CONSTRAINT ck_csa_description CHECK (
        CHAR_LENGTH(TRIM(description)) > 0
        AND CHAR_LENGTH(description) <= 4000
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
