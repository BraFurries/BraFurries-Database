-- Visibility of the *individual exam grade*, never the selection's final outcome.
-- Existing stages remain PRIVATE; any change after publication is forbidden in API.
ALTER TABLE `recruitment_stage_attempt_policies`
  ADD COLUMN `score_visibility` VARCHAR(24) NOT NULL DEFAULT 'PRIVATE',
  ADD CONSTRAINT `ck_rsap_score_visibility` CHECK
    (`score_visibility` IN ('PRIVATE','AFTER_SUBMISSION'));
