-- Add a UTC release instant to the frozen per-stage numeric score policy.
-- Existing PRIVATE and AFTER_SUBMISSION rows remain unchanged and valid.
-- No gabarito or selection outcome is ever disclosed by this migration.
ALTER TABLE `recruitment_stage_attempt_policies`
  DROP CONSTRAINT `ck_rsap_score_visibility`,
  ADD COLUMN `score_release_at` DATETIME(6) NULL,
  ADD CONSTRAINT `ck_rsap_score_visibility` CHECK (
    (`score_visibility` IN ('PRIVATE','AFTER_SUBMISSION')
      AND `score_release_at` IS NULL)
    OR (`score_visibility`='AT_TIME' AND `score_release_at` IS NOT NULL)
  );
