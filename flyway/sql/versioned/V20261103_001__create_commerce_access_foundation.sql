-- BraFurries-exclusive commercial authorization. This is not a Community feature.
-- No commerce table has community_id. Do not reuse CommunityCapability or Discord store grants.
-- The trusted owner user id and the official BraFurries Community id live in API configuration.
-- All tables start empty; nobody receives permissions automatically after migration.

CREATE TABLE `commerce_authorized_users` (
    `user_id` INT(11) NOT NULL,
    `approved_by_user_id` INT(11) NOT NULL,
    `approved_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`user_id`),
    KEY `idx_cau_approver` (`approved_by_user_id`, `approved_at`),
    CONSTRAINT `fk_cau_user` FOREIGN KEY (`user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_cau_approver` FOREIGN KEY (`approved_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Approved people have a personal ceiling. Revoking approval deletes its
-- grants transactionally; a later approval starts with zero permissions.
CREATE TABLE `commerce_user_permissions` (
    `user_id` INT(11) NOT NULL,
    `permission_code` VARCHAR(40) NOT NULL,
    `granted_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`user_id`, `permission_code`),
    KEY `idx_cup_grantor` (`granted_by_user_id`, `created_at`),
    CONSTRAINT `fk_cup_approved_user` FOREIGN KEY (`user_id`)
        REFERENCES `commerce_authorized_users` (`user_id`)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT `fk_cup_grantor` FOREIGN KEY (`granted_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_cup_permission` CHECK (`permission_code` IN (
        'ARTWORKS_MANAGE', 'CONTRACTS_MANAGE', 'SUPPLIERS_MANAGE',
        'PRODUCTS_MANAGE', 'SALES_MANAGE', 'FINANCE_VIEW',
        'SETTLEMENTS_MANAGE', 'PAYMENTS_RECORD'
    ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- The role FK points to the existing internal Time role, not a Discord role.
-- The API checks that the role belongs to BraFurries before granting it.
CREATE TABLE `commerce_role_permissions` (
    `role_id` INT(11) NOT NULL,
    `permission_code` VARCHAR(40) NOT NULL,
    `granted_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`role_id`, `permission_code`),
    KEY `idx_crp_grantor` (`granted_by_user_id`, `created_at`),
    CONSTRAINT `fk_crp_role` FOREIGN KEY (`role_id`)
        REFERENCES `community_team_roles` (`id`)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT `fk_crp_grantor` FOREIGN KEY (`granted_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_crp_permission` CHECK (`permission_code` IN (
        'ARTWORKS_MANAGE', 'CONTRACTS_MANAGE', 'SUPPLIERS_MANAGE',
        'PRODUCTS_MANAGE', 'SALES_MANAGE', 'FINANCE_VIEW',
        'SETTLEMENTS_MANAGE', 'PAYMENTS_RECORD'
    ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Changes to access always leave an immutable audit record, even when a user
-- is deauthorized or a Time role is removed later.
CREATE TABLE `commerce_access_audit` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor_user_id` INT(11) NOT NULL,
    `action` VARCHAR(32) NOT NULL,
    `subject_user_id` INT(11) NULL,
    `role_id` INT(11) NULL,
    `permission_code` VARCHAR(40) NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_caa_time` (`created_at`, `id`),
    KEY `idx_caa_subject` (`subject_user_id`, `created_at`),
    KEY `idx_caa_actor` (`actor_user_id`, `created_at`),
    CONSTRAINT `fk_caa_actor` FOREIGN KEY (`actor_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_caa_subject` FOREIGN KEY (`subject_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT `ck_caa_action` CHECK (`action` IN (
        'PERSON_APPROVED', 'PERSON_REVOKED', 'PERSON_PERMISSION_GRANTED',
        'PERSON_PERMISSION_REVOKED', 'ROLE_PERMISSION_GRANTED',
        'ROLE_PERMISSION_REVOKED'
    ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
