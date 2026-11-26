-- Operational production request; historical READY/DELIVERED rows remain valid.
-- No stock reservation, supplier order or confirmed sale is created.
ALTER TABLE commerce_orders
    ADD COLUMN production_requested_at DATETIME(6) NULL,
    DROP CONSTRAINT ck_co_status,
    ADD CONSTRAINT ck_co_status CHECK (
        (status='OPEN' AND production_requested_at IS NULL AND ready_at IS NULL
            AND delivered_on IS NULL AND cancelled_at IS NULL AND cancellation_reason IS NULL)
        OR (status='IN_PRODUCTION' AND production_requested_at IS NOT NULL AND ready_at IS NULL
            AND delivered_on IS NULL AND cancelled_at IS NULL AND cancellation_reason IS NULL)
        OR (status='READY' AND ready_at IS NOT NULL AND delivered_on IS NULL
            AND cancelled_at IS NULL AND cancellation_reason IS NULL)
        OR (status='DELIVERED' AND ready_at IS NOT NULL AND delivered_on IS NOT NULL
            AND cancelled_at IS NULL AND cancellation_reason IS NULL)
        OR (status='CANCELLED' AND delivered_on IS NULL
            AND cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL)
    );

-- Preserve pre-migration readiness while rejecting new readiness without a request.
DELIMITER $
CREATE TRIGGER trg_co_ready_requires_production
BEFORE UPDATE ON commerce_orders
FOR EACH ROW
BEGIN
    IF NEW.status='READY' AND OLD.status<>'READY'
        AND (OLD.status<>'IN_PRODUCTION' OR NEW.production_requested_at IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Encaminhe a encomenda para produção antes de marcar pronta';
    END IF;
END$
DELIMITER ;
