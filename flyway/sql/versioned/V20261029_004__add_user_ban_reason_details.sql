-- Optional staff-only context for one administrative ban action.
-- Existing records keep NULL; no backfill or changes to reasons/tenant/FKs.
-- Execute only after V20261029_002 and V20261029_003.
ALTER TABLE `user_bans`
    ADD COLUMN `reason_details` VARCHAR(2048) NULL AFTER `reason`;
