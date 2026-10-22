-- Process-scoped optimistic locking across draft metadata, stages, and forms.
-- API requires expected revision and atomically increments while holding the process row.
-- Existing rows begin at revision 0; no data is deleted or rewritten.
ALTER TABLE `recruitment_processes`
    ADD COLUMN `draft_revision` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0;
