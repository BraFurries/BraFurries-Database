-- Scoring policy is frozen with the stage attempt policy (only API DRAFT writes).
-- NULL pair preserves historic draft policies; preflight rejects incomplete exams.
ALTER TABLE `recruitment_stage_attempt_policies`
  ADD COLUMN `passing_percentage` DECIMAL(5,2) NULL,
  ADD COLUMN `result_strategy` VARCHAR(12) NULL,
  ADD CONSTRAINT `ck_rsap_grade_pair` CHECK (
    (`passing_percentage` IS NULL AND `result_strategy` IS NULL)
    OR (`passing_percentage` BETWEEN 1.00 AND 100.00
        AND `result_strategy` IN ('BEST','LAST'))
  );

-- The attempt has an immutable own ID, and the additional tenant-qualified unique
-- index ensures grade FK integrity even when numeric IDs collide elsewhere.
ALTER TABLE `recruitment_candidate_attempts`
  ADD UNIQUE KEY `uq_rca_tenant_identity` (`community_id`,`id`);

-- Only server-computed grades, never a candidate-provided score.
CREATE TABLE `recruitment_candidate_attempt_grades` (
  `community_id` INT(11) NOT NULL,
  `attempt_id` BIGINT(20) UNSIGNED NOT NULL,
  `earned_points` INT(10) UNSIGNED NOT NULL,
  `possible_points` INT(10) UNSIGNED NOT NULL,
  `correct_questions` SMALLINT UNSIGNED NOT NULL,
  `total_questions` SMALLINT UNSIGNED NOT NULL,
  `passing_percentage` DECIMAL(5,2) NOT NULL,
  `passed` TINYINT(1) NOT NULL,
  `graded_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`community_id`,`attempt_id`),
  CONSTRAINT `fk_rcag_attempt` FOREIGN KEY (`community_id`,`attempt_id`)
    REFERENCES `recruitment_candidate_attempts` (`community_id`,`id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_rcag_points` CHECK (
    `possible_points` BETWEEN 1 AND 1000000
    AND `earned_points`<=`possible_points`
    AND `total_questions` BETWEEN 1 AND 60
    AND `correct_questions`<=`total_questions`
    AND `passing_percentage` BETWEEN 1.00 AND 100.00
    AND `passed` IN (0,1)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
