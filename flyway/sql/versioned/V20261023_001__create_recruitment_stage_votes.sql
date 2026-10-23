-- V1 collective ballots: distinct, immutable votes from evaluators with a submitted assessment.
-- No result publication, no DML on legacy records, no change in Community boundaries.
CREATE TABLE `recruitment_stage_votes` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `community_id` INT(11) NOT NULL,
  `application_id` BIGINT(20) UNSIGNED NOT NULL,
  `stage_id` BIGINT(20) UNSIGNED NOT NULL,
  `voter_user_id` INT(11) NOT NULL,
  `choice` VARCHAR(12) NOT NULL,
  `cast_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rsv_single_ballot`
    (`community_id`, `application_id`, `stage_id`, `voter_user_id`),
  KEY `idx_rsv_tally` (`community_id`, `application_id`, `stage_id`, `choice`),
  KEY `fk_rsv_voter` (`community_id`, `voter_user_id`),
  CONSTRAINT `fk_rsv_assessment` FOREIGN KEY
    (`community_id`, `application_id`, `stage_id`, `voter_user_id`)
    REFERENCES `recruitment_stage_assessments`
      (`community_id`, `application_id`, `stage_id`, `evaluator_user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_rsv_voter` FOREIGN KEY (`community_id`, `voter_user_id`)
    REFERENCES `user_community_status` (`community_id`, `user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_rsv_choice` CHECK (`choice` IN ('APPROVE','REJECT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Explicit decision provenance avoids treating a vote majority as a staff override.
-- Existing manual decisions remain MANUAL by default and are not modified.
ALTER TABLE `recruitment_stage_decisions`
  ADD COLUMN `decision_source` VARCHAR(24) NOT NULL DEFAULT 'MANUAL',
  ADD CONSTRAINT `ck_rsd_source`
    CHECK (`decision_source` IN ('MANUAL','VOTE_MAJORITY','VOTE_TIE_REJECT','VOTE_TIE_OVERRIDE'));
