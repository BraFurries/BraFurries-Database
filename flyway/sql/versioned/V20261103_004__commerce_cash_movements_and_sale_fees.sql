-- Private BraFurries commercial finance V1 extension.
-- Never add Community tenancy or mix with the Discord virtual store.
-- This migration must follow V20261103_001..003. No DML/backfill of legacy data.

-- Payment processing fees belong to the sale itself, not the manually
-- entered cash-movement ledger. This prevents counting them twice.
-- PERCENT_GROSS royalties still use original gross_amount (not net receipt).
ALTER TABLE `commerce_sales`
    ADD COLUMN `payment_method` VARCHAR(24) NOT NULL DEFAULT 'UNSPECIFIED',
    ADD COLUMN `processing_provider` VARCHAR(120) NULL,
    ADD COLUMN `processing_fee_percent` DECIMAL(9,4) NOT NULL DEFAULT 0.0000,
    ADD COLUMN `processing_fee_fixed` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN `processing_fee_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN `net_receipt_amount` DECIMAL(18,2)
        AS (`gross_amount` - `processing_fee_amount`) PERSISTENT,
    ADD CONSTRAINT `ck_cs_payment_method` CHECK (`payment_method` IN (
        'UNSPECIFIED','CASH','PIX','CARD_DEBIT','CARD_CREDIT',
        'BANK_TRANSFER','BANK_SLIP','OTHER'
    )),
    ADD CONSTRAINT `ck_cs_fee_percent` CHECK
        (`processing_fee_percent` BETWEEN 0 AND 100),
    ADD CONSTRAINT `ck_cs_fee_fixed` CHECK
        (`processing_fee_fixed` >= 0),
    ADD CONSTRAINT `ck_cs_fee_amount` CHECK
        (`processing_fee_amount` >= 0
         AND `processing_fee_amount` <= `gross_amount`
         AND `processing_fee_amount` =
             ROUND(`gross_amount` * `processing_fee_percent` / 100
                   + `processing_fee_fixed`, 2));

-- Separate financial privilege: recording miscellaneous cash movements is
-- NOT implied by SALES_MANAGE, PAYMENTS_RECORD or FINANCE_VIEW.
ALTER TABLE `commerce_user_permissions`
    DROP CONSTRAINT `ck_cup_permission`,
    ADD CONSTRAINT `ck_cup_permission` CHECK (`permission_code` IN (
        'ARTWORKS_MANAGE', 'CONTRACTS_MANAGE', 'SUPPLIERS_MANAGE',
        'PRODUCTS_MANAGE', 'SALES_MANAGE', 'FINANCE_VIEW',
        'SETTLEMENTS_MANAGE', 'PAYMENTS_RECORD', 'CASHFLOW_MANAGE'
    ));

ALTER TABLE `commerce_role_permissions`
    DROP CONSTRAINT `ck_crp_permission`,
    ADD CONSTRAINT `ck_crp_permission` CHECK (`permission_code` IN (
        'ARTWORKS_MANAGE', 'CONTRACTS_MANAGE', 'SUPPLIERS_MANAGE',
        'PRODUCTS_MANAGE', 'SALES_MANAGE', 'FINANCE_VIEW',
        'SETTLEMENTS_MANAGE', 'PAYMENTS_RECORD', 'CASHFLOW_MANAGE'
    ));

-- Append-only miscellaneous cash events, with at most one compensating
-- reversal per original. Funding stays separate from operating income.
-- Contributions marked REPAYABLE are funding/liabilities, never profit.
-- No automatic repayment/payment is initiated by this ledger.
CREATE TABLE `commerce_cash_movements` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `request_key` CHAR(36) NOT NULL,
    `request_sha256` CHAR(64) NOT NULL,
    `movement_type` VARCHAR(16) NOT NULL,
    `event_kind` VARCHAR(12) NOT NULL DEFAULT 'POSTED',
    `reversal_of_id` BIGINT UNSIGNED NULL,
    `amount` DECIMAL(18,2) NOT NULL,
    `signed_amount` DECIMAL(18,2)
        AS (
            CASE WHEN (`movement_type` IN ('INCOME','CONTRIBUTION')
                           AND `event_kind` = 'POSTED')
                     OR (`movement_type` = 'EXPENSE'
                           AND `event_kind` = 'REVERSAL')
                 THEN `amount` ELSE -`amount` END
        ) PERSISTENT,
    `occurred_on` DATE NOT NULL,
    `category` VARCHAR(80) NOT NULL,
    `description` VARCHAR(500) NOT NULL,
    `counterparty_label` VARCHAR(160) NOT NULL,
    `counterparty_user_id` INT(11) NULL,
    `contributor_type` VARCHAR(20) NULL,
    `contribution_nature` VARCHAR(16) NULL,
    `payment_method` VARCHAR(24) NOT NULL,
    `external_reference` VARCHAR(120) NULL,
    `notes` TEXT NULL,
    `reversal_reason` VARCHAR(500) NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ccm_request_key` (`request_key`),
    UNIQUE KEY `uq_ccm_reversal` (`reversal_of_id`),
    KEY `idx_ccm_occurred_type` (`occurred_on`,`movement_type`,`id`),
    KEY `idx_ccm_counterparty` (`counterparty_user_id`,`occurred_on`),
    KEY `idx_ccm_creator` (`created_by_user_id`,`created_at`),
    CONSTRAINT `fk_ccm_counterparty` FOREIGN KEY (`counterparty_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_ccm_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_ccm_reversal` FOREIGN KEY (`reversal_of_id`)
        REFERENCES `commerce_cash_movements` (`id`)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_ccm_type` CHECK
        (`movement_type` IN ('INCOME','EXPENSE','CONTRIBUTION')),
    CONSTRAINT `ck_ccm_kind` CHECK (
        (`event_kind` = 'POSTED' AND `reversal_of_id` IS NULL
                                  AND `reversal_reason` IS NULL)
        OR (`event_kind` = 'REVERSAL' AND `reversal_of_id` IS NOT NULL
                                      AND `reversal_reason` IS NOT NULL)
    ),
    CONSTRAINT `ck_ccm_amount` CHECK (`amount` > 0),
    CONSTRAINT `ck_ccm_required_labels` CHECK (
        CHAR_LENGTH(TRIM(`category`)) > 0
        AND CHAR_LENGTH(TRIM(`description`)) > 0
        AND CHAR_LENGTH(TRIM(`counterparty_label`)) > 0
    ),
    CONSTRAINT `ck_ccm_contribution` CHECK (
        (`movement_type` = 'CONTRIBUTION'
          AND `contributor_type` IS NOT NULL
          AND `contribution_nature` IS NOT NULL
          AND `contributor_type` IN ('OWNER','STAFF','COMMUNITY_MEMBER','EXTERNAL')
          AND `contribution_nature` IN ('NON_REPAYABLE','REPAYABLE'))
        OR (`movement_type` <> 'CONTRIBUTION'
          AND `contributor_type` IS NULL AND `contribution_nature` IS NULL)
    ),
    CONSTRAINT `ck_ccm_payment_method` CHECK (`payment_method` IN (
        'CASH','PIX','CARD_DEBIT','CARD_CREDIT',
        'BANK_TRANSFER','BANK_SLIP','OTHER'
    ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
