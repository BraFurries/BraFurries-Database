-- Optional, private, mutable autosave on the existing candidate attempt.
-- Final answers_json remains immutable outside the existing submit transition.
ALTER TABLE `recruitment_candidate_attempts`
  ADD COLUMN `draft_answers_json` LONGTEXT NULL,
  ADD COLUMN `draft_revision` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN `draft_saved_at` DATETIME(6) NULL,
  ADD CONSTRAINT `ck_rca_draft_answers_json` CHECK
    (`draft_answers_json` IS NULL OR JSON_VALID(`draft_answers_json`)),
  ADD CONSTRAINT `ck_rca_draft_metadata` CHECK
    ((`draft_revision` = 0 AND `draft_saved_at` IS NULL AND `draft_answers_json` IS NULL)
     OR (`draft_revision` > 0 AND `draft_saved_at` IS NOT NULL));
