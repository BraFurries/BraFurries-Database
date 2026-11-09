-- BraFurries private physical preorders/reservations. Not Community economy.
-- Orders are OPERATIONAL: they do NOT reduce sold_quantity, book revenue,
-- or accrue artist royalties. Confirmed physical sales remain authoritative.
-- MariaDB/Flyway only. No destructive change to existing commerce_sales.

CREATE TABLE commerce_orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    request_key CHAR(36) NOT NULL,
    request_sha256 CHAR(64) NOT NULL,
    channel VARCHAR(16) NOT NULL DEFAULT 'DIRECT',
    external_reference VARCHAR(120) NULL,
    buyer_label VARCHAR(160) NOT NULL,
    ordered_on DATE NOT NULL,
    expected_delivery_on DATE NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'OPEN',
    total_amount DECIMAL(18,2) NOT NULL,
    notes TEXT NULL,
    created_by_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by_user_id INT(11) NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    ready_at DATETIME(6) NULL,
    delivered_on DATE NULL,
    cancelled_at DATETIME(6) NULL,
    cancellation_reason VARCHAR(500) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_co_request (request_key),
    UNIQUE KEY uq_co_channel_ref (channel,external_reference),
    KEY idx_co_status_due (status,expected_delivery_on,id),
    KEY idx_co_buyer (buyer_label,id),
    CONSTRAINT fk_co_creator FOREIGN KEY (created_by_user_id)
        REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_co_updater FOREIGN KEY (updated_by_user_id)
        REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_co_channel CHECK (channel IN ('EVENT','DIRECT','ONLINE','OTHER')),
    CONSTRAINT ck_co_total CHECK (total_amount >= 0),
    CONSTRAINT ck_co_dates CHECK (
        expected_delivery_on IS NULL OR expected_delivery_on >= ordered_on),
    CONSTRAINT ck_co_status CHECK (
        (status='OPEN' AND ready_at IS NULL AND delivered_on IS NULL
            AND cancelled_at IS NULL AND cancellation_reason IS NULL)
        OR (status='READY' AND ready_at IS NOT NULL AND delivered_on IS NULL
            AND cancelled_at IS NULL AND cancellation_reason IS NULL)
        OR (status='DELIVERED' AND ready_at IS NOT NULL AND delivered_on IS NOT NULL
            AND cancelled_at IS NULL AND cancellation_reason IS NULL)
        OR (status='CANCELLED' AND delivered_on IS NULL
            AND cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Flexible line can reference catalog product or a one-off custom product;
-- size is free text to preserve historical apparel formats.
CREATE TABLE commerce_order_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NULL,
    item_label VARCHAR(180) NOT NULL,
    size_label VARCHAR(64) NULL,
    quantity INT UNSIGNED NOT NULL,
    unit_price_snapshot DECIMAL(18,2) NOT NULL,
    line_amount DECIMAL(18,2) NOT NULL,
    PRIMARY KEY (id),
    KEY idx_coi_order (order_id,id),
    KEY idx_coi_product (product_id,id),
    CONSTRAINT fk_coi_order FOREIGN KEY (order_id)
        REFERENCES commerce_orders (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_coi_product FOREIGN KEY (product_id)
        REFERENCES commerce_products (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_coi_quantity CHECK (quantity BETWEEN 1 AND 100000),
    CONSTRAINT ck_coi_price CHECK (unit_price_snapshot >= 0),
    CONSTRAINT ck_coi_amount CHECK (
        line_amount = quantity * unit_price_snapshot)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Payment receipt ledger is an order tracking aid, NOT cash/finance posting.
-- Reversals are compensating immutable rows; no DML deletion of receipts.
CREATE TABLE commerce_order_payment_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    request_key CHAR(36) NOT NULL,
    request_sha256 CHAR(64) NOT NULL,
    event_kind VARCHAR(12) NOT NULL,
    original_event_id BIGINT UNSIGNED NULL,
    amount DECIMAL(18,2) NOT NULL,
    received_on DATE NOT NULL,
    payment_method VARCHAR(16) NOT NULL,
    external_reference VARCHAR(120) NULL,
    notes VARCHAR(500) NULL,
    recorded_by_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_cope_request (request_key),
    UNIQUE KEY uq_cope_reversal (original_event_id),
    KEY idx_cope_order_date (order_id,created_at,id),
    CONSTRAINT fk_cope_order FOREIGN KEY (order_id)
        REFERENCES commerce_orders (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_cope_origin FOREIGN KEY (original_event_id)
        REFERENCES commerce_order_payment_events (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_cope_actor FOREIGN KEY (recorded_by_user_id)
        REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_cope_kind CHECK (
        (event_kind='RECEIPT' AND original_event_id IS NULL AND amount > 0)
        OR (event_kind='REVERSAL' AND original_event_id IS NOT NULL AND amount < 0)
    ),
    CONSTRAINT ck_cope_method CHECK (
        payment_method IN ('PIX','CASH','CARD_DEBIT','CARD_CREDIT',
                           'BANK_TRANSFER','BANK_SLIP','OTHER')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Event rows are append-only. Corrections are new REVERSAL records.
CREATE TRIGGER trg_cope_no_update
BEFORE UPDATE ON commerce_order_payment_events
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Registro de recebimento é imutável; use estorno';

CREATE TRIGGER trg_cope_no_delete
BEFORE DELETE ON commerce_order_payment_events
FOR EACH ROW SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT='Registro de recebimento não pode ser excluído';
