-- BraFurries-only commercial correction journal.
-- Requires catalog, cash and payment baseline. Apply after V20261109_004:
-- payout original rows are immutable; corrections are separate append-only entries.
-- No existing financial row is modified or backfilled.

CREATE TABLE commerce_production_batch_revisions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    batch_id BIGINT UNSIGNED NOT NULL,
    before_json LONGTEXT NOT NULL,
    after_json LONGTEXT NOT NULL,
    reason VARCHAR(500) NOT NULL,
    actor_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_cpbr_batch (batch_id,id),
    CONSTRAINT fk_cpbr_batch FOREIGN KEY (batch_id)
        REFERENCES commerce_production_batches(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_cpbr_actor FOREIGN KEY (actor_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_cpbr_json CHECK (JSON_VALID(before_json) AND JSON_VALID(after_json)),
    CONSTRAINT ck_cpbr_reason CHECK (CHAR_LENGTH(TRIM(reason)) BETWEEN 3 AND 500)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE commerce_payment_metadata_revisions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    payment_id BIGINT UNSIGNED NOT NULL,
    previous_reference VARCHAR(120) NOT NULL,
    updated_reference VARCHAR(120) NOT NULL,
    previous_notes TEXT NULL,
    updated_notes TEXT NULL,
    reason VARCHAR(500) NOT NULL,
    actor_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_cpmr_payment (payment_id,id),
    CONSTRAINT fk_cpmr_payment FOREIGN KEY (payment_id)
        REFERENCES commerce_payments(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_cpmr_actor FOREIGN KEY (actor_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_cpmr_ref CHECK (CHAR_LENGTH(TRIM(updated_reference)) BETWEEN 1 AND 120),
    CONSTRAINT ck_cpmr_reason CHECK (CHAR_LENGTH(TRIM(reason)) BETWEEN 3 AND 500)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE commerce_cash_metadata_revisions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    movement_id BIGINT UNSIGNED NOT NULL,
    previous_description VARCHAR(500) NOT NULL,
    updated_description VARCHAR(500) NOT NULL,
    previous_reference VARCHAR(120) NULL,
    updated_reference VARCHAR(120) NULL,
    previous_notes TEXT NULL,
    updated_notes TEXT NULL,
    reason VARCHAR(500) NOT NULL,
    actor_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_ccmr_movement (movement_id,id),
    CONSTRAINT fk_ccmr_movement FOREIGN KEY (movement_id)
        REFERENCES commerce_cash_movements(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_ccmr_actor FOREIGN KEY (actor_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_ccmr_desc CHECK (CHAR_LENGTH(TRIM(updated_description)) BETWEEN 1 AND 500),
    CONSTRAINT ck_ccmr_reason CHECK (CHAR_LENGTH(TRIM(reason)) BETWEEN 3 AND 500)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Append-only evidence. Operational changes still use the normal API audit.
CREATE TRIGGER trg_cpbr_no_update
BEFORE UPDATE ON commerce_production_batch_revisions
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Historico de correcoes de lote nao pode ser alterado';

CREATE TRIGGER trg_cpbr_no_delete
BEFORE DELETE ON commerce_production_batch_revisions
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Historico de correcoes de lote nao pode ser excluido';

CREATE TRIGGER trg_cpmr_no_update
BEFORE UPDATE ON commerce_payment_metadata_revisions
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Retificacao de pagamento nao pode ser alterada';

CREATE TRIGGER trg_cpmr_no_delete
BEFORE DELETE ON commerce_payment_metadata_revisions
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Retificacao de pagamento nao pode ser excluida';

CREATE TRIGGER trg_ccmr_no_update
BEFORE UPDATE ON commerce_cash_metadata_revisions
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Retificacao de caixa nao pode ser alterada';

CREATE TRIGGER trg_ccmr_no_delete
BEFORE DELETE ON commerce_cash_metadata_revisions
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Retificacao de caixa nao pode ser excluida';
