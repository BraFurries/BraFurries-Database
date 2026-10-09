-- Contraction step for the legacy Portaria invite bypass TEXT field.
--
-- Apply only after API and Coddy no longer read/write
-- portaria_base_config.invite_bypass_codes.
--
-- Fail closed if any environment still contains a non-empty legacy value.
SET @legacy_invite_bypass_count = (
    SELECT COUNT(*)
    FROM `portaria_base_config`
    WHERE `invite_bypass_codes` IS NOT NULL
      AND TRIM(`invite_bypass_codes`) <> ''
);

SET @drop_legacy_invite_bypass_sql = IF(
    @legacy_invite_bypass_count = 0,
    'ALTER TABLE `portaria_base_config` DROP COLUMN IF EXISTS `invite_bypass_codes`',
    'SIGNAL SQLSTATE ''45000'' SET MESSAGE_TEXT = ''Cannot drop invite_bypass_codes: non-empty legacy values still exist'''
);

PREPARE drop_legacy_invite_bypass_stmt
    FROM @drop_legacy_invite_bypass_sql;
EXECUTE drop_legacy_invite_bypass_stmt;
DEALLOCATE PREPARE drop_legacy_invite_bypass_stmt;
