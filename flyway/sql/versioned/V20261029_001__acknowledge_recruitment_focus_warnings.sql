-- Candidate acknowledgements are per attempt and strictly tenant-scoped through
-- the existing composite attempt identity. Existing attempted focus events remain intact.
-- Additive migration; legacy clients continue working with the default zero value.
ALTER TABLE `recruitment_candidate_attempts`
  ADD COLUMN `focus_losses_acknowledged` TINYINT UNSIGNED NOT NULL DEFAULT 0
    AFTER `focus_losses`,
  ADD CONSTRAINT `ck_rca_focus_acknowledged`
    CHECK (`focus_losses_acknowledged` <= `focus_losses`);
