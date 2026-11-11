-- Voice XP audit rows are transient calibration diagnostics, not the XP ledger.
-- This index enables oldest-first bounded retention without scanning every guild.
-- Apply BEFORE enabling the API's opt-in cleanup; no historical rows are deleted.
-- Existing audit rows, user_level, voice_sessions and voice_xp_daily_metrics stay intact.
--
-- Production: confirm table shape and available free disk before applying.
-- This ALTER may take time on a large InnoDB table; do not run during peak traffic.
ALTER TABLE `voice_xp_audit_log`
    ADD KEY `idx_voice_xp_audit_retention` (`created_at`, `id`);
