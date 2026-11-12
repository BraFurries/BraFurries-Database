-- BraFurries commercial contracts: model text + immutable printable preparations.
-- Expand-only: legacy templates keep full_text NULL and signed agreements remain untouched.
-- Contracts are platform-level (NOT Community tenants). Only API may authorize access.
-- Apply by an approved manual rollout BEFORE enabling the new API endpoints.

ALTER TABLE commerce_contract_templates
    ADD COLUMN full_text LONGTEXT NULL AFTER description;

-- A preparation is an UNSIGNED immutable PDF awaiting signatures.
-- This table never grants commercial rights; only commerce_artwork_contracts
-- gains an ACTIVE agreement after staff uploads an externally signed PDF.
CREATE TABLE commerce_contract_preparations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    artwork_id BIGINT UNSIGNED NOT NULL,
    template_id BIGINT UNSIGNED NOT NULL,
    artist_user_id INT(11) NOT NULL,
    template_name_snapshot VARCHAR(160) NOT NULL,
    full_text_snapshot LONGTEXT NOT NULL,
    modality_snapshot VARCHAR(32) NOT NULL,
    royalty_method_snapshot VARCHAR(24) NOT NULL,
    royalty_percent_snapshot DECIMAL(9,4) NULL,
    royalty_fixed_snapshot DECIMAL(18,2) NULL,
    one_time_amount DECIMAL(18,2) NOT NULL,
    effective_from DATE NOT NULL,
    effective_until DATE NULL,
    contractor_name VARCHAR(180) NOT NULL,
    contractor_document VARCHAR(32) NOT NULL,
    contractor_address VARCHAR(500) NOT NULL,
    contractor_representative VARCHAR(180) NULL,
    artist_name VARCHAR(180) NOT NULL,
    artist_document VARCHAR(32) NOT NULL,
    artist_address VARCHAR(500) NOT NULL,
    artist_representative VARCHAR(180) NULL,
    generated_storage_key VARCHAR(512) NOT NULL,
    generated_sha256 CHAR(64) NOT NULL,
    generated_bytes BIGINT UNSIGNED NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    pending_artwork_id BIGINT UNSIGNED AS
        (CASE WHEN status='PENDING' THEN artwork_id ELSE NULL END) PERSISTENT,
    signed_contract_id BIGINT UNSIGNED NULL,
    created_by_user_id INT(11) NOT NULL,
    completed_by_user_id INT(11) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    completed_at DATETIME(6) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_ccprep_pending_artwork (pending_artwork_id),
    UNIQUE KEY uq_ccprep_generated_key (generated_storage_key),
    UNIQUE KEY uq_ccprep_signed_contract (signed_contract_id),
    KEY idx_ccprep_artwork_created (artwork_id, created_at),
    KEY idx_ccprep_template (template_id),
    KEY idx_ccprep_artist (artist_user_id),
    CONSTRAINT fk_ccprep_artwork_artist FOREIGN KEY (artwork_id, artist_user_id)
        REFERENCES commerce_artworks(id, artist_user_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ccprep_template FOREIGN KEY (template_id)
        REFERENCES commerce_contract_templates(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ccprep_signed FOREIGN KEY (signed_contract_id)
        REFERENCES commerce_artwork_contracts(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ccprep_creator FOREIGN KEY (created_by_user_id)
        REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ccprep_completer FOREIGN KEY (completed_by_user_id)
        REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_ccprep_status CHECK (status IN ('PENDING','SIGNED','CANCELLED')),
    CONSTRAINT ck_ccprep_dates CHECK (effective_until IS NULL OR effective_until >= effective_from),
    CONSTRAINT ck_ccprep_one_time CHECK (one_time_amount >= 0),
    CONSTRAINT ck_ccprep_file CHECK (generated_bytes > 0 AND CHAR_LENGTH(generated_sha256)=64),
    CONSTRAINT ck_ccprep_finality CHECK (
        (status='PENDING' AND signed_contract_id IS NULL
         AND completed_at IS NULL AND completed_by_user_id IS NULL)
        OR
        (status='CANCELLED' AND signed_contract_id IS NULL
         AND completed_at IS NOT NULL AND completed_by_user_id IS NOT NULL)
        OR
        (status='SIGNED' AND signed_contract_id IS NOT NULL
         AND completed_at IS NOT NULL AND completed_by_user_id IS NOT NULL)
    ),
    CONSTRAINT ck_ccprep_modality CHECK (modality_snapshot IN
        ('ONE_TIME_FEE','RIGHTS_ASSIGNMENT','EXCLUSIVE_LICENSE',
         'NONEXCLUSIVE_LICENSE','ROYALTY','HYBRID')),
    CONSTRAINT ck_ccprep_terms CHECK (CHAR_LENGTH(TRIM(full_text_snapshot)) > 0),
    CONSTRAINT ck_ccprep_royalties CHECK (
        (royalty_method_snapshot='NONE' AND royalty_percent_snapshot IS NULL
            AND royalty_fixed_snapshot IS NULL)
        OR
        (royalty_method_snapshot IN ('PERCENT_GROSS','PERCENT_NET')
            AND royalty_percent_snapshot IS NOT NULL
            AND royalty_percent_snapshot BETWEEN 0 AND 100
            AND royalty_fixed_snapshot IS NULL)
        OR
        (royalty_method_snapshot IN ('FIXED_UNIT','FIXED_MONTH')
            AND royalty_fixed_snapshot IS NOT NULL
            AND royalty_fixed_snapshot >= 0 AND royalty_percent_snapshot IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Never expose generated_storage_key in API list responses.
-- Abandoning a preparation preserves its PDF and audit trail.
-- Legacy signed contracts (without preparation) stay valid.
