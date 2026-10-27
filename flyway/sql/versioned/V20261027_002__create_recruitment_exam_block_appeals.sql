-- Candidate-requested technical review of a focus-loss block, per original attempt.
-- Every row is tenant-scoped, non-destructive and immutable in its request details.
-- This is separate from appeals against the selection's final result.
CREATE TABLE `recruitment_exam_block_appeals` (
  `community_id` INT(11) NOT NULL,
  `attempt_id` BIGINT(20) UNSIGNED NOT NULL,
  `application_id` BIGINT(20) UNSIGNED NOT NULL,
  `stage_id` BIGINT(20) UNSIGNED NOT NULL,
  `candidate_user_id` INT(11) NOT NULL,
  `reason` VARCHAR(2000) NOT NULL,
  `status` VARCHAR(12) NOT NULL DEFAULT 'PENDING',
  `requested_at` DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
  `reviewed_by_user_id` INT(11) NULL,
  `review_reason` VARCHAR(2000) NULL,
  `reviewed_at` DATETIME(6) NULL,
  PRIMARY KEY (`community_id`,`attempt_id`),
  KEY `idx_reba_pending` (`community_id`,`status`,`requested_at`),
  CONSTRAINT `fk_reba_attempt` FOREIGN KEY
    (`community_id`,`application_id`,`stage_id`,`attempt_id`)
    REFERENCES `recruitment_candidate_attempts`
      (`community_id`,`application_id`,`stage_id`,`id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_reba_candidate` FOREIGN KEY (`community_id`,`candidate_user_id`)
    REFERENCES `user_community_status` (`community_id`,`user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_reba_reviewer` FOREIGN KEY (`community_id`,`reviewed_by_user_id`)
    REFERENCES `user_community_status` (`community_id`,`user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_reba_reason` CHECK (CHAR_LENGTH(TRIM(`reason`)) BETWEEN 20 AND 2000),
  CONSTRAINT `ck_reba_status` CHECK (`status` IN ('PENDING','APPROVED','DENIED')),
  CONSTRAINT `ck_reba_review` CHECK (
    (`status`='PENDING' AND `reviewed_by_user_id` IS NULL AND `review_reason` IS NULL AND `reviewed_at` IS NULL)
    OR (`status`<>'PENDING' AND `reviewed_by_user_id` IS NOT NULL
      AND `review_reason` IS NOT NULL AND CHAR_LENGTH(TRIM(`review_reason`)) BETWEEN 20 AND 2000
      AND `reviewed_at` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
