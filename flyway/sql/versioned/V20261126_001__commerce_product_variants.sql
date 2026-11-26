-- Physical merchandise only. NULL variant denotes legacy/unclassified or simple products.
CREATE TABLE commerce_product_attributes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(60) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_cpa_product_name (product_id,name),
    UNIQUE KEY uq_cpa_product_attr (product_id,id),
    CONSTRAINT fk_cpattr_product FOREIGN KEY (product_id) REFERENCES commerce_products(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE commerce_product_attribute_values (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id BIGINT UNSIGNED NOT NULL,
    attribute_id BIGINT UNSIGNED NOT NULL,
    label VARCHAR(60) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_cpav_label (attribute_id,label),
    UNIQUE KEY uq_cpav_scope (product_id,attribute_id,id),
    CONSTRAINT fk_cpav_attr FOREIGN KEY (product_id,attribute_id)
        REFERENCES commerce_product_attributes(product_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE commerce_product_variants (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id BIGINT UNSIGNED NOT NULL,
    combination_sha256 CHAR(64) NOT NULL,
    label VARCHAR(255) NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    suggested_price DECIMAL(18,2) NULL,
    estimated_unit_cost DECIMAL(18,2) NULL,
    created_by_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_cpv_combination (product_id,combination_sha256),
    UNIQUE KEY uq_cpv_scope (product_id,id),
    CONSTRAINT fk_cpv_product FOREIGN KEY (product_id) REFERENCES commerce_products(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_cpv_actor FOREIGN KEY (created_by_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_cpv_active CHECK (active IN (0,1)),
    CONSTRAINT ck_cpv_price CHECK (suggested_price IS NULL OR suggested_price >= 0),
    CONSTRAINT ck_cpv_cost CHECK (estimated_unit_cost IS NULL OR estimated_unit_cost >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE commerce_product_variant_values (
    product_id BIGINT UNSIGNED NOT NULL,
    variant_id BIGINT UNSIGNED NOT NULL,
    attribute_id BIGINT UNSIGNED NOT NULL,
    value_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (variant_id,attribute_id),
    CONSTRAINT fk_cpvv_variant FOREIGN KEY (product_id,variant_id)
        REFERENCES commerce_product_variants(product_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_cpvv_value FOREIGN KEY (product_id,attribute_id,value_id)
        REFERENCES commerce_product_attribute_values(product_id,attribute_id,id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE commerce_order_items
    ADD COLUMN variant_id BIGINT UNSIGNED NULL,
    ADD COLUMN variant_label_snapshot VARCHAR(255) NULL,
    ADD KEY idx_coi_variant (product_id,variant_id),
    ADD CONSTRAINT fk_coi_variant FOREIGN KEY (product_id,variant_id)
        REFERENCES commerce_product_variants(product_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_coi_variant CHECK (
        (variant_id IS NULL AND variant_label_snapshot IS NULL)
        OR (product_id IS NOT NULL AND variant_id IS NOT NULL AND variant_label_snapshot IS NOT NULL));

ALTER TABLE commerce_production_batches
    ADD COLUMN variant_id BIGINT UNSIGNED NULL,
    ADD COLUMN variant_label_snapshot VARCHAR(255) NULL,
    ADD KEY idx_cpb_variant (product_id,variant_id),
    ADD UNIQUE KEY uq_cpb_variant_scope (id,product_id,variant_id),
    ADD CONSTRAINT fk_cpb_variant FOREIGN KEY (product_id,variant_id)
        REFERENCES commerce_product_variants(product_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_cpb_variant CHECK (
        (variant_id IS NULL AND variant_label_snapshot IS NULL)
        OR (variant_id IS NOT NULL AND variant_label_snapshot IS NOT NULL));

ALTER TABLE commerce_sale_items
    ADD COLUMN variant_id BIGINT UNSIGNED NULL,
    ADD COLUMN variant_label_snapshot VARCHAR(255) NULL,
    ADD KEY idx_csi_variant (product_id,variant_id),
    ADD CONSTRAINT fk_csi_variant_batch FOREIGN KEY (production_batch_id,product_id,variant_id)
        REFERENCES commerce_production_batches(id,product_id,variant_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_csi_variant CHECK (
        (variant_id IS NULL AND variant_label_snapshot IS NULL)
        OR (variant_id IS NOT NULL AND variant_label_snapshot IS NOT NULL));
