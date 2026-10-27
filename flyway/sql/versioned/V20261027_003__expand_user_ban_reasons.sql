-- The legacy unique_ban(community_id, date, reason) rejects unrelated members
-- banned on the same day for the same reason. Its uniqueness is not a valid
-- moderation invariant. Keep a supporting tenant/date index for history queries
-- and for the foreign key on community_id.
--
-- user_bans.reason was VARCHAR(256), rejecting detailed moderation rationale
-- with DataError. All historical values are preserved by this widening change.
-- Contract: API UserBan.reason and Coddy /ban accept up to 2048 characters.
ALTER TABLE `user_bans`
    ADD INDEX `idx_user_bans_community_date` (`community_id`, `date`),
    DROP INDEX `unique_ban`,
    MODIFY COLUMN `reason` VARCHAR(2048) NOT NULL;
