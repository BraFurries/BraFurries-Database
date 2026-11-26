-- Logical production lot; existing batch rows remain inventory/cost authorities.
-- Legacy rows retain NULL group_id and their original IDs and sale references.
CREATE TABLE commerce_production_lot_groups (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id BIGINT UNSIGNED NOT NULL,
    created_by_user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_cplg_scope (id,product_id),
    CONSTRAINT fk_cplg_product FOREIGN KEY (product_id) REFERENCES commerce_products(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_cplg_actor FOREIGN KEY (created_by_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE commerce_production_batches
    ADD COLUMN lot_group_id BIGINT UNSIGNED NULL,
    ADD UNIQUE KEY uq_cpb_group_variant (lot_group_id,variant_id),
    ADD KEY idx_cpb_group_product (lot_group_id,product_id),
    ADD CONSTRAINT fk_cpb_group FOREIGN KEY (lot_group_id,product_id)
        REFERENCES commerce_production_lot_groups(id,product_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_cpb_group_variant CHECK (lot_group_id IS NULL OR variant_id IS NOT NULL);
