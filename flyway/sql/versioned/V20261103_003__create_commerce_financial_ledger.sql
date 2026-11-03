-- BraFurries-only financial ledger, independent from Community/Discord virtual store.
-- All monetary values BRL DECIMAL; no mutable contract or product values in sales.
-- V1: confirmed physical sales, complete cancellations before settlement, accrued
-- royalties for PERCENT_GROSS/FIXED_UNIT, monthly settlement and manual paid records.
-- Percentage NET/FIXED_MONTH require explicit contractual basis and are NOT accrued here.

-- One artist-period mutex row for sale/refund vs settlement concurrency.
CREATE TABLE `commerce_period_locks` (
    `artist_user_id` INT(11) NOT NULL,
    `period_year` SMALLINT UNSIGNED NOT NULL,
    `period_month` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`artist_user_id`, `period_year`, `period_month`),
    CONSTRAINT `fk_cpl_artist` FOREIGN KEY (`artist_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_cpl_year` CHECK (`period_year` BETWEEN 2000 AND 2200),
    CONSTRAINT `ck_cpl_month` CHECK (`period_month` BETWEEN 1 AND 12)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_sales` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `request_key` CHAR(36) NOT NULL,
    `request_sha256` CHAR(64) NOT NULL,
    `channel` VARCHAR(16) NOT NULL,
    `external_reference` VARCHAR(120) NULL,
    `buyer_label` VARCHAR(160) NULL,
    `sold_on` DATE NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'CONFIRMED',
    `gross_amount` DECIMAL(18,2) NOT NULL,
    `notes` TEXT NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `cancelled_by_user_id` INT(11) NULL,
    `cancelled_at` DATETIME(6) NULL,
    `cancellation_reason` VARCHAR(500) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_csales_request` (`request_key`),
    UNIQUE KEY `uq_csales_channel_ref` (`channel`, `external_reference`),
    KEY `idx_csales_sold` (`sold_on`, `status`),
    KEY `idx_csales_actor` (`created_by_user_id`, `created_at`),
    CONSTRAINT `fk_csales_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_csales_canceller` FOREIGN KEY (`cancelled_by_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_csales_channel` CHECK (`channel` IN ('EVENT','DIRECT','ONLINE','OTHER')),
    CONSTRAINT `ck_csales_status` CHECK (`status` IN ('CONFIRMED','CANCELLED')),
    CONSTRAINT `ck_csales_gross` CHECK (`gross_amount` >= 0),
    CONSTRAINT `ck_csales_cancel` CHECK (
        (`status` = 'CONFIRMED' AND `cancelled_by_user_id` IS NULL
            AND `cancelled_at` IS NULL AND `cancellation_reason` IS NULL)
        OR (`status` = 'CANCELLED' AND `cancelled_by_user_id` IS NOT NULL
            AND `cancelled_at` IS NOT NULL AND `cancellation_reason` IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Validate that a stocked batch is the same product as the sale item.
ALTER TABLE `commerce_production_batches`
    ADD UNIQUE KEY `uq_cpb_id_product` (`id`, `product_id`);

CREATE TABLE `commerce_sale_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sale_id` BIGINT UNSIGNED NOT NULL,
    `product_id` BIGINT UNSIGNED NOT NULL,
    `production_batch_id` BIGINT UNSIGNED NOT NULL,
    `quantity` INT UNSIGNED NOT NULL,
    `unit_price_snapshot` DECIMAL(18,2) NOT NULL,
    `line_gross_amount` DECIMAL(18,2) NOT NULL,
    `line_production_cost_snapshot` DECIMAL(18,2) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_csi_sale_batch` (`sale_id`, `production_batch_id`),
    KEY `idx_csi_batch` (`production_batch_id`),
    KEY `idx_csi_product` (`product_id`),
    CONSTRAINT `fk_csi_sale` FOREIGN KEY (`sale_id`)
        REFERENCES `commerce_sales` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_csi_batch_product` FOREIGN KEY (`production_batch_id`, `product_id`)
        REFERENCES `commerce_production_batches` (`id`, `product_id`)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_csi_product` FOREIGN KEY (`product_id`)
        REFERENCES `commerce_products` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_csi_quantity` CHECK (`quantity` > 0),
    CONSTRAINT `ck_csi_price` CHECK (`unit_price_snapshot` >= 0),
    CONSTRAINT `ck_csi_line_amount` CHECK (`line_gross_amount` =
        `quantity` * `unit_price_snapshot`),
    CONSTRAINT `ck_csi_cost` CHECK (`line_production_cost_snapshot` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Immutable financial events (SALE and reversal on cancellation).
-- Cancellation is booked against the sale's original accounting month, before
-- that month is settled. Historical accruals are never overwritten/deleted.
CREATE TABLE `commerce_royalty_accruals` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sale_item_id` BIGINT UNSIGNED NOT NULL,
    `artwork_id` BIGINT UNSIGNED NOT NULL,
    `contract_id` BIGINT UNSIGNED NOT NULL,
    `artist_user_id` INT(11) NOT NULL,
    `period_year` SMALLINT UNSIGNED NOT NULL,
    `period_month` TINYINT UNSIGNED NOT NULL,
    `event_kind` VARCHAR(12) NOT NULL,
    `original_accrual_id` BIGINT UNSIGNED NULL,
    `royalty_method_snapshot` VARCHAR(24) NOT NULL,
    `contract_rate_snapshot` DECIMAL(9,4) NULL,
    `fixed_unit_snapshot` DECIMAL(18,2) NULL,
    `allocation_percent_snapshot` DECIMAL(9,4) NOT NULL,
    `basis_amount_snapshot` DECIMAL(18,2) NOT NULL,
    `amount` DECIMAL(18,2) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cra_origin` (`original_accrual_id`),
    UNIQUE KEY `uq_cra_sale_art_kind` (`sale_item_id`, `artwork_id`, `event_kind`),
    KEY `idx_cra_period` (`artist_user_id`, `period_year`, `period_month`, `id`),
    KEY `idx_cra_contract` (`contract_id`),
    CONSTRAINT `fk_cra_item` FOREIGN KEY (`sale_item_id`)
        REFERENCES `commerce_sale_items` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_cra_artwork` FOREIGN KEY (`artwork_id`)
        REFERENCES `commerce_artworks` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_cra_contract` FOREIGN KEY (`contract_id`)
        REFERENCES `commerce_artwork_contracts` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_cra_artist` FOREIGN KEY (`artist_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_cra_origin` FOREIGN KEY (`original_accrual_id`)
        REFERENCES `commerce_royalty_accruals` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_cra_month` CHECK (`period_month` BETWEEN 1 AND 12),
    CONSTRAINT `ck_cra_year` CHECK (`period_year` BETWEEN 2000 AND 2200),
    CONSTRAINT `ck_cra_kind` CHECK (
        (`event_kind`='SALE' AND `original_accrual_id` IS NULL AND `amount` >= 0)
        OR (`event_kind`='REVERSAL' AND `original_accrual_id` IS NOT NULL AND `amount` <= 0)
    ),
    CONSTRAINT `ck_cra_method` CHECK (
        (`royalty_method_snapshot`='PERCENT_GROSS'
            AND `contract_rate_snapshot` BETWEEN 0 AND 100
            AND `contract_rate_snapshot` IS NOT NULL AND `fixed_unit_snapshot` IS NULL)
        OR (`royalty_method_snapshot`='FIXED_UNIT'
            AND `fixed_unit_snapshot` IS NOT NULL AND `fixed_unit_snapshot` >= 0
            AND `contract_rate_snapshot` IS NULL)
    ),
    CONSTRAINT `ck_cra_allocation` CHECK
        (`allocation_percent_snapshot` BETWEEN 0 AND 100),
    CONSTRAINT `ck_cra_basis` CHECK (`basis_amount_snapshot` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_settlements` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `artist_user_id` INT(11) NOT NULL,
    `period_year` SMALLINT UNSIGNED NOT NULL,
    `period_month` TINYINT UNSIGNED NOT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    `total_amount` DECIMAL(18,2) NOT NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `approved_by_user_id` INT(11) NULL,
    `approved_at` DATETIME(6) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cst_artist_period` (`artist_user_id`, `period_year`, `period_month`),
    KEY `idx_cst_period_status` (`period_year`, `period_month`, `status`),
    CONSTRAINT `fk_cst_artist` FOREIGN KEY (`artist_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_cst_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_cst_approver` FOREIGN KEY (`approved_by_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_cst_month` CHECK (`period_month` BETWEEN 1 AND 12),
    CONSTRAINT `ck_cst_year` CHECK (`period_year` BETWEEN 2000 AND 2200),
    CONSTRAINT `ck_cst_total` CHECK (`total_amount` >= 0),
    CONSTRAINT `ck_cst_status` CHECK
        (`status` IN ('DRAFT','APPROVED','PARTIALLY_PAID','PAID')),
    CONSTRAINT `ck_cst_approval` CHECK (
        (`status`='DRAFT' AND `approved_by_user_id` IS NULL AND `approved_at` IS NULL)
        OR (`status`<>'DRAFT' AND `approved_by_user_id` IS NOT NULL AND `approved_at` IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_settlement_items` (
    `settlement_id` BIGINT UNSIGNED NOT NULL,
    `accrual_id` BIGINT UNSIGNED NOT NULL,
    `amount_snapshot` DECIMAL(18,2) NOT NULL,
    PRIMARY KEY (`settlement_id`, `accrual_id`),
    UNIQUE KEY `uq_csti_accrual` (`accrual_id`),
    CONSTRAINT `fk_csti_settlement` FOREIGN KEY (`settlement_id`)
        REFERENCES `commerce_settlements` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_csti_accrual` FOREIGN KEY (`accrual_id`)
        REFERENCES `commerce_royalty_accruals` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_payments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `settlement_id` BIGINT UNSIGNED NOT NULL,
    `request_key` CHAR(36) NOT NULL,
    `amount` DECIMAL(18,2) NOT NULL,
    `paid_on` DATE NOT NULL,
    `external_reference` VARCHAR(120) NOT NULL,
    `notes` TEXT NULL,
    `recorded_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cpay_request` (`request_key`),
    UNIQUE KEY `uq_cpay_ref` (`settlement_id`, `external_reference`),
    KEY `idx_cpay_settlement` (`settlement_id`, `paid_on`),
    CONSTRAINT `fk_cpay_settlement` FOREIGN KEY (`settlement_id`)
        REFERENCES `commerce_settlements` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `fk_cpay_recorder` FOREIGN KEY (`recorded_by_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT `ck_cpay_amount` CHECK (`amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_finance_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor_user_id` INT(11) NOT NULL,
    `entity_type` VARCHAR(32) NOT NULL,
    `entity_id` BIGINT UNSIGNED NOT NULL,
    `action` VARCHAR(40) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_cfa_entity` (`entity_type`, `entity_id`, `created_at`),
    KEY `idx_cfa_actor` (`actor_user_id`, `created_at`),
    CONSTRAINT `fk_cfa_actor` FOREIGN KEY (`actor_user_id`)
        REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
