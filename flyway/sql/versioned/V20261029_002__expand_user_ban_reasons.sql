-- A reason is not a unique business key for moderation actions.
-- Production baseline has unique_ban(community_id, date, reason), but some
-- historical pre-baseline states do not. Both must be supported by Flyway.
--
-- MariaDB 10.6: create the non-unique tenant/date lookup before dropping the
-- old key so the FK on user_bans.community_id always has a supporting index.
CREATE INDEX IF NOT EXISTS `idx_user_bans_community_date`
    ON `user_bans` (`community_id`, `date`);

DROP INDEX IF EXISTS `unique_ban` ON `user_bans`;

-- Preserve IDs, existing records and dependent ban-effect ledger references.
-- The API/Coddy contract will expand from 256 to 2048 only after this migration.
ALTER TABLE `user_bans`
    MODIFY COLUMN `reason` VARCHAR(2048) NOT NULL;
