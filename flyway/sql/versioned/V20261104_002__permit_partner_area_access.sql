-- BraFurries-wide administrative area permission, reusing the audited
-- owner-approved person + active official Time role intersection.
-- Unlike Community capabilities, this does not grant access across tenants.
-- All current data stays intact; no person/role is granted PARTNERS_MANAGE
-- implicitly. Legacy ROLE_ADMIN access to partners is handled by API policy.
ALTER TABLE `commerce_user_permissions`
    DROP CONSTRAINT `ck_cup_permission`,
    ADD CONSTRAINT `ck_cup_permission` CHECK (`permission_code` IN (
        'ARTWORKS_MANAGE', 'CONTRACTS_MANAGE', 'SUPPLIERS_MANAGE',
        'PRODUCTS_MANAGE', 'SALES_MANAGE', 'FINANCE_VIEW',
        'SETTLEMENTS_MANAGE', 'PAYMENTS_RECORD', 'CASHFLOW_MANAGE',
        'PARTNERS_MANAGE'
    ));

ALTER TABLE `commerce_role_permissions`
    DROP CONSTRAINT `ck_crp_permission`,
    ADD CONSTRAINT `ck_crp_permission` CHECK (`permission_code` IN (
        'ARTWORKS_MANAGE', 'CONTRACTS_MANAGE', 'SUPPLIERS_MANAGE',
        'PRODUCTS_MANAGE', 'SALES_MANAGE', 'FINANCE_VIEW',
        'SETTLEMENTS_MANAGE', 'PAYMENTS_RECORD', 'CASHFLOW_MANAGE',
        'PARTNERS_MANAGE'
    ));
