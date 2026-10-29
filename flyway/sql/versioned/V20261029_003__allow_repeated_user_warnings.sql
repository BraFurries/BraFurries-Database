-- Warnings are separate moderation actions identified by their immutable id.
-- Legacy unique_warning(user_id,community_id,date,reason) collapses distinct
-- same-day actions and can reject a legitimate second warning.
-- Import idempotency remains the Coddy control-plane contract: lock the parent
-- user row, check the legacy DATE-granularity key, then insert if absent.
-- Keep user_warnings.reason at VARCHAR(1024) for Discord embed/API compatibility.
CREATE INDEX IF NOT EXISTS `idx_user_warnings_community_user_date`
  ON `user_warnings` (`community_id`, `user_id`, `date`);

DROP INDEX IF EXISTS `unique_warning` ON `user_warnings`;
