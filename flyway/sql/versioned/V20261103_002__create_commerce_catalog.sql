-- BraFurries private commercial catalog. No Community tenancy; the API owns authorization.
-- All tables are initially empty. Never reuse Discord virtual store and inventory.
-- V20261103_001 must be applied before use by the API.

CREATE TABLE `commerce_contract_templates` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(160) NOT NULL,
    `description` TEXT NULL,
    `modality` VARCHAR(32) NOT NULL,
    `royalty_method` VARCHAR(24) NOT NULL DEFAULT 'NONE',
    `royalty_percent` DECIMAL(9,4) NULL,
    `royalty_fixed_amount` DECIMAL(18,2) NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cct_name` (`name`),
    KEY `idx_cct_status` (`active`, `id`),
    CONSTRAINT `fk_cct_author` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cct_modality` CHECK (`modality` IN
        ('ONE_TIME_FEE', 'RIGHTS_ASSIGNMENT', 'EXCLUSIVE_LICENSE',
         'NONEXCLUSIVE_LICENSE', 'ROYALTY', 'HYBRID')),
    CONSTRAINT `ck_cct_royalty_method` CHECK (`royalty_method` IN
        ('NONE', 'PERCENT_GROSS', 'PERCENT_NET', 'FIXED_UNIT', 'FIXED_MONTH')),
    CONSTRAINT `ck_cct_percent` CHECK (`royalty_percent` IS NULL
        OR (`royalty_percent` >= 0 AND `royalty_percent` <= 100)),
    CONSTRAINT `ck_cct_fixed` CHECK (`royalty_fixed_amount` IS NULL
        OR `royalty_fixed_amount` >= 0),
    CONSTRAINT `ck_cct_royalty_basis` CHECK (
        (`royalty_method` = 'NONE' AND `royalty_percent` IS NULL AND `royalty_fixed_amount` IS NULL)
        OR (`royalty_method` IN ('PERCENT_GROSS','PERCENT_NET')
            AND `royalty_percent` IS NOT NULL AND `royalty_fixed_amount` IS NULL)
        OR (`royalty_method` IN ('FIXED_UNIT','FIXED_MONTH')
            AND `royalty_fixed_amount` IS NOT NULL AND `royalty_percent` IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_artworks` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(180) NOT NULL,
    `description` TEXT NULL,
    `artist_user_id` INT(11) NOT NULL,
    `creation_cost` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `status` VARCHAR(16) NOT NULL DEFAULT 'DRAFT',
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ca_id_artist` (`id`, `artist_user_id`),
    KEY `idx_ca_artist_status` (`artist_user_id`, `status`),
    KEY `idx_ca_status` (`status`, `id`),
    CONSTRAINT `fk_ca_artist` FOREIGN KEY (`artist_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_ca_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_ca_creation_cost` CHECK (`creation_cost` >= 0),
    CONSTRAINT `ck_ca_status` CHECK (`status` IN ('DRAFT','ACTIVE','ARCHIVED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Signed agreements are distinct from reusable templates. Copy the actual
-- financial terms when signing: later template edits must never alter contracts.
-- Only one active contract per artwork; historical agreements remain immutable.
CREATE TABLE `commerce_artwork_contracts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `artwork_id` BIGINT UNSIGNED NOT NULL,
    `template_id` BIGINT UNSIGNED NOT NULL,
    `artist_user_id` INT(11) NOT NULL,
    `modality_snapshot` VARCHAR(32) NOT NULL,
    `royalty_method_snapshot` VARCHAR(24) NOT NULL,
    `royalty_percent_snapshot` DECIMAL(9,4) NULL,
    `royalty_fixed_snapshot` DECIMAL(18,2) NULL,
    `one_time_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `effective_from` DATE NOT NULL,
    `effective_until` DATE NULL,
    `signed_storage_key` VARCHAR(512) NOT NULL,
    `signed_sha256` CHAR(64) NOT NULL,
    `signed_bytes` BIGINT UNSIGNED NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    `active_artwork_id` BIGINT UNSIGNED AS
        (CASE WHEN `status` = 'ACTIVE' THEN `artwork_id` ELSE NULL END) PERSISTENT,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `ended_at` DATETIME(6) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cac_active_artwork` (`active_artwork_id`),
    UNIQUE KEY `uq_cac_document_key` (`signed_storage_key`),
    KEY `idx_cac_artwork_created` (`artwork_id`, `created_at`),
    KEY `idx_cac_artist` (`artist_user_id`),
    KEY `fk_cac_template` (`template_id`),
    CONSTRAINT `fk_cac_artwork_artist` FOREIGN KEY (`artwork_id`, `artist_user_id`)
        REFERENCES `commerce_artworks` (`id`, `artist_user_id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cac_template` FOREIGN KEY (`template_id`)
        REFERENCES `commerce_contract_templates` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cac_artist` FOREIGN KEY (`artist_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cac_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cac_status` CHECK (`status` IN ('ACTIVE','TERMINATED')),
    CONSTRAINT `ck_cac_modality` CHECK (`modality_snapshot` IN
        ('ONE_TIME_FEE','RIGHTS_ASSIGNMENT','EXCLUSIVE_LICENSE',
         'NONEXCLUSIVE_LICENSE','ROYALTY','HYBRID')),
    CONSTRAINT `ck_cac_dates` CHECK (`effective_until` IS NULL OR `effective_until` >= `effective_from`),
    CONSTRAINT `ck_cac_royalties` CHECK (
        (`royalty_method_snapshot` = 'NONE'
            AND `royalty_percent_snapshot` IS NULL AND `royalty_fixed_snapshot` IS NULL)
        OR (`royalty_method_snapshot` IN ('PERCENT_GROSS','PERCENT_NET')
            AND `royalty_percent_snapshot` IS NOT NULL AND `royalty_percent_snapshot` BETWEEN 0 AND 100
            AND `royalty_fixed_snapshot` IS NULL)
        OR (`royalty_method_snapshot` IN ('FIXED_UNIT','FIXED_MONTH')
            AND `royalty_fixed_snapshot` IS NOT NULL AND `royalty_fixed_snapshot` >= 0
            AND `royalty_percent_snapshot` IS NULL)
    ),
    CONSTRAINT `ck_cac_one_time` CHECK (`one_time_amount` >= 0),
    CONSTRAINT `ck_cac_signed_file` CHECK (`signed_bytes` > 0 AND CHAR_LENGTH(`signed_sha256`) = 64)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_suppliers` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(180) NOT NULL,
    `contact_name` VARCHAR(140) NULL,
    `email` VARCHAR(255) NULL,
    `phone` VARCHAR(64) NULL,
    `notes` TEXT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cs_name` (`name`),
    CONSTRAINT `fk_cs_author` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commerce_products` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sku` VARCHAR(80) NOT NULL,
    `name` VARCHAR(180) NOT NULL,
    `description` TEXT NULL,
    `estimated_unit_cost` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `suggested_price` DECIMAL(18,2) NOT NULL,
    `preferred_supplier_id` BIGINT UNSIGNED NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cp_sku` (`sku`),
    KEY `idx_cp_active` (`active`, `id`),
    KEY `idx_cp_supplier` (`preferred_supplier_id`),
    CONSTRAINT `fk_cp_author` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cp_supplier` FOREIGN KEY (`preferred_supplier_id`)
        REFERENCES `commerce_suppliers` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cp_est_cost` CHECK (`estimated_unit_cost` >= 0),
    CONSTRAINT `ck_cp_price` CHECK (`suggested_price` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Multiple artworks per item (and artwork across multiple products).
-- Royalty allocation is deliberately explicit; NULL means "not yet agreed".
CREATE TABLE `commerce_product_artworks` (
    `product_id` BIGINT UNSIGNED NOT NULL,
    `artwork_id` BIGINT UNSIGNED NOT NULL,
    `royalty_allocation_percent` DECIMAL(9,4) NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`product_id`, `artwork_id`),
    KEY `idx_cpa_artwork` (`artwork_id`, `product_id`),
    CONSTRAINT `fk_cpa_product` FOREIGN KEY (`product_id`)
        REFERENCES `commerce_products` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cpa_artwork` FOREIGN KEY (`artwork_id`)
        REFERENCES `commerce_artworks` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cpa_author` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cpa_royalty` CHECK (`royalty_allocation_percent` IS NULL
        OR (`royalty_allocation_percent` >= 0 AND `royalty_allocation_percent` <= 100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Historical production cost per supplier and batch, independent of
-- the product estimate. Inventory movements will be modeled with sales later.
CREATE TABLE `commerce_production_batches` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `product_id` BIGINT UNSIGNED NOT NULL,
    `supplier_id` BIGINT UNSIGNED NOT NULL,
    `quantity` INT UNSIGNED NOT NULL,
    `unit_cost` DECIMAL(18,2) NOT NULL,
    `additional_cost` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `total_cost` DECIMAL(18,2) NOT NULL,
    `produced_on` DATE NOT NULL,
    `reference` VARCHAR(160) NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_cpb_product_date` (`product_id`, `produced_on`),
    KEY `idx_cpb_supplier` (`supplier_id`, `produced_on`),
    CONSTRAINT `fk_cpb_product` FOREIGN KEY (`product_id`)
        REFERENCES `commerce_products` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cpb_supplier` FOREIGN KEY (`supplier_id`)
        REFERENCES `commerce_suppliers` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cpb_author` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cpb_quantity` CHECK (`quantity` > 0),
    CONSTRAINT `ck_cpb_unit_cost` CHECK (`unit_cost` >= 0),
    CONSTRAINT `ck_cpb_additional` CHECK (`additional_cost` >= 0),
    CONSTRAINT `ck_cpb_total_cost` CHECK
        (`total_cost` = ROUND(`quantity` * `unit_cost` + `additional_cost`, 2))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- No secrets, PII or private object keys in catalog audit metadata.
CREATE TABLE `commerce_catalog_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor_user_id` INT(11) NOT NULL,
    `entity_type` VARCHAR(32) NOT NULL,
    `entity_id` BIGINT UNSIGNED NOT NULL,
    `action` VARCHAR(32) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_cca_entity` (`entity_type`, `entity_id`, `created_at`),
    KEY `idx_cca_actor` (`actor_user_id`, `created_at`),
    CONSTRAINT `fk_cca_actor` FOREIGN KEY (`actor_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
