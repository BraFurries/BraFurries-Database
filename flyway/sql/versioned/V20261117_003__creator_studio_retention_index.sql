-- Creator Studio: bounded status/completion-time scan for the one-year policy.
-- No backfill, deletion or cleanup is executed by this migration.
-- The API retention worker is disabled by default during the pilot.
ALTER TABLE creator_studio_commissions
    ADD INDEX idx_csc_retention (status, completed_at, id);
