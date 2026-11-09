-- BraFurries only: immutable artist-payment reversal events, not editable transfers.
-- Schema authority: Database. Production is manually migrated only after approved backup.
-- Existing payments remain PAYMENT with amount >0 and identical financial totals.
-- Compensating REVERSAL is a negative amount linked to exactly one original payment.
ALTER TABLE commerce_payments
    ADD COLUMN event_kind VARCHAR(12) NOT NULL DEFAULT 'PAYMENT' AFTER amount,
    ADD COLUMN original_payment_id BIGINT UNSIGNED NULL AFTER event_kind,
    ADD COLUMN reversal_reason VARCHAR(500) NULL AFTER original_payment_id,
    ADD COLUMN reversed_by_user_id INT(11) NULL AFTER reversal_reason,
    ADD COLUMN reversed_at DATETIME(6) NULL AFTER reversed_by_user_id,
    ADD UNIQUE KEY uq_cpay_reversal_origin (original_payment_id),
    ADD UNIQUE KEY uq_cpay_id_settlement (id,settlement_id),
    ADD KEY idx_cpay_payment_event (settlement_id,event_kind),
    ADD CONSTRAINT fk_cpay_reversal_origin
        FOREIGN KEY (original_payment_id,settlement_id)
        REFERENCES commerce_payments(id,settlement_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_cpay_reverser FOREIGN KEY (reversed_by_user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Replace the legacy always-positive constraint, preserving positive PAYMENTS
-- and allowing negative REVERSALS with complete provenance. Neither may be zero.
ALTER TABLE commerce_payments
    DROP CONSTRAINT ck_cpay_amount,
    ADD CONSTRAINT ck_cpay_signed_amount CHECK (
        (event_kind = 'PAYMENT' AND amount > 0
         AND original_payment_id IS NULL AND reversal_reason IS NULL
         AND reversed_by_user_id IS NULL AND reversed_at IS NULL)
        OR
        (event_kind = 'REVERSAL' AND amount < 0
         AND original_payment_id IS NOT NULL AND reversal_reason IS NOT NULL
         AND CHAR_LENGTH(TRIM(reversal_reason)) >= 3
         AND reversed_by_user_id IS NOT NULL AND reversed_at IS NOT NULL)
    );

-- Audit is performed by the API in commerce_finance_audit; the original payment
-- id, amount, external reference, date, recorder and bytes are never overwritten.
