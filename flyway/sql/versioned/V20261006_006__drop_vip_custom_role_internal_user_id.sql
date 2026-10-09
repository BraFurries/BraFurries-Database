-- Contraction step for account-scoped VIP custom roles.
--
-- Apply only after every API/Coddy consumer has been deployed without any
-- dependency on user_custom_roles.user_id.
--
-- Foreign-key names are legacy-schema dependent, so discover and remove every
-- FK attached to user_id before dropping the column. Indexes that only exist
-- to support the removed column are handled by MariaDB when the column drops.

SET @vip_custom_role_drop_user_fks = (
    SELECT GROUP_CONCAT(
        CONCAT('DROP FOREIGN KEY `', CONSTRAINT_NAME, '`')
        ORDER BY CONSTRAINT_NAME
        SEPARATOR ', '
    )
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_custom_roles'
      AND COLUMN_NAME = 'user_id'
      AND REFERENCED_TABLE_NAME IS NOT NULL
);

SET @vip_custom_role_drop_user_fk_sql = IF(
    @vip_custom_role_drop_user_fks IS NULL,
    'SELECT 1',
    CONCAT(
        'ALTER TABLE `user_custom_roles` ',
        @vip_custom_role_drop_user_fks
    )
);

PREPARE vip_custom_role_drop_user_fk_stmt
    FROM @vip_custom_role_drop_user_fk_sql;
EXECUTE vip_custom_role_drop_user_fk_stmt;
DEALLOCATE PREPARE vip_custom_role_drop_user_fk_stmt;

ALTER TABLE `user_custom_roles`
    DROP COLUMN IF EXISTS `user_id`;
