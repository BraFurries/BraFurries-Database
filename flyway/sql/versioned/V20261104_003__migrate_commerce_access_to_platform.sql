-- BraFurries platform-level permissions. Financial/commerce business tables stay unchanged.
-- The four legacy access tables are renamed, NOT copied: their approvals, grants,
-- audit rows, timestamps, PKs, FKs and indexes survive without duplicate authorities.
-- Run AFTER V20261104_002, which may already have been applied manually in production.
-- Verify all four source names exist and the target names do not before applying.
CREATE TABLE `platform_permission_catalog` (
    `code` VARCHAR(40) NOT NULL,
    `area` VARCHAR(32) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `description` VARCHAR(500) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`code`),
    KEY `idx_platform_permission_area` (`area`, `code`),
    CONSTRAINT `ck_platform_permission_active` CHECK (`active` IN (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `platform_permission_catalog` (`code`, `area`, `label`, `description`) VALUES
('ARTWORKS_MANAGE',     'COMMERCE', 'Gerenciar artes', 'Cadastrar obras, artistas e custos de criação'),
('CONTRACTS_MANAGE',    'COMMERCE', 'Gerenciar contratos', 'Cadastrar modelos e consultar contratos privados'),
('SUPPLIERS_MANAGE',    'COMMERCE', 'Gerenciar fornecedores', 'Manter fornecedores e informações de produção'),
('PRODUCTS_MANAGE',     'COMMERCE', 'Gerenciar produtos', 'Gerenciar catálogo, estoque e lotes'),
('SALES_MANAGE',        'COMMERCE', 'Gerenciar vendas', 'Registrar e cancelar vendas'),
('FINANCE_VIEW',        'COMMERCE', 'Consultar financeiro', 'Consultar resultados, caixa e valores financeiros'),
('SETTLEMENTS_MANAGE',  'COMMERCE', 'Gerenciar fechamentos', 'Gerenciar fechamentos e royalties'),
('PAYMENTS_RECORD',     'COMMERCE', 'Registrar pagamentos', 'Registrar pagamentos e repasses'),
('CASHFLOW_MANAGE',     'COMMERCE', 'Gerenciar caixa e aportes', 'Registrar movimentos e estornos'),
('PARTNERS_MANAGE',     'PARTNERS', 'Gerenciar parceiros', 'Cadastrar, editar e remover parceiros');

RENAME TABLE
    `commerce_authorized_users` TO `platform_authorized_users`,
    `commerce_user_permissions` TO `platform_user_permissions`,
    `commerce_role_permissions` TO `platform_role_permissions`,
    `commerce_access_audit` TO `platform_access_audit`;

-- The catalog replaces the brittle per-table CHECK code lists.
-- Permission IDs stay the same; only their containing ACL is generalized.
ALTER TABLE `platform_user_permissions`
    DROP CONSTRAINT `ck_cup_permission`,
    ADD CONSTRAINT `fk_platform_up_catalog` FOREIGN KEY (`permission_code`)
        REFERENCES `platform_permission_catalog` (`code`) ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE `platform_role_permissions`
    DROP CONSTRAINT `ck_crp_permission`,
    ADD CONSTRAINT `fk_platform_rp_catalog` FOREIGN KEY (`permission_code`)
        REFERENCES `platform_permission_catalog` (`code`) ON UPDATE RESTRICT ON DELETE RESTRICT;

-- Audit is immutable and references the catalog only for non-null codes. Prevent
-- deleting a permission that appears in historical audit evidence.
ALTER TABLE `platform_access_audit`
    ADD CONSTRAINT `fk_platform_audit_catalog` FOREIGN KEY (`permission_code`)
        REFERENCES `platform_permission_catalog` (`code`) ON UPDATE RESTRICT ON DELETE RESTRICT;
