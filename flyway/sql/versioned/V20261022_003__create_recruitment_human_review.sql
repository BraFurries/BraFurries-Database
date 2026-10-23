-- Human review V1: scoped stage assignments and independent reviewer assessments.
-- Additive, no DML. Schema authority: BraFurries-Database. MariaDB 10.6.
-- Existing review endpoints MUST become assignment-scoped before feature activation.

-- Reuses existing unique key uk_ctr_community_id_id on legacy Team roles.

CREATE TABLE `recruitment_stage_reviewers` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `community_id` INT(11) NOT NULL,
  `process_version_id` BIGINT(20) UNSIGNED NOT NULL,
  `stage_id` BIGINT(20) UNSIGNED NOT NULL,
  `user_id` INT(11) NULL,
  `role_id` INT(11) NULL,
  `created_by_user_id` INT(11) NOT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rsr_user` (`community_id`, `stage_id`, `user_id`),
  UNIQUE KEY `uq_rsr_role` (`community_id`, `stage_id`, `role_id`),
  KEY `idx_rsr_version` (`community_id`, `process_version_id`, `stage_id`),
  KEY `fk_rsr_role` (`community_id`, `role_id`),
  KEY `fk_rsr_creator` (`created_by_user_id`),
  CONSTRAINT `fk_rsr_stage` FOREIGN KEY (`community_id`, `process_version_id`, `stage_id`)
    REFERENCES `recruitment_stages` (`community_id`, `process_version_id`, `id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_rsr_user` FOREIGN KEY (`community_id`, `user_id`)
    REFERENCES `user_community_status` (`community_id`, `user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_rsr_role` FOREIGN KEY (`community_id`, `role_id`)
    REFERENCES `community_team_roles` (`community_id`, `id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_rsr_creator` FOREIGN KEY (`created_by_user_id`)
    REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_rsr_target` CHECK (
    (`user_id` IS NOT NULL AND `role_id` IS NULL) OR
    (`user_id` IS NULL AND `role_id` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- A submitted individual assessment is immutable in the V1 API.
-- Recommendation/score are NOT stage approval or candidate-facing decisions.
CREATE TABLE `recruitment_stage_assessments` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `community_id` INT(11) NOT NULL,
  `application_id` BIGINT(20) UNSIGNED NOT NULL,
  `stage_id` BIGINT(20) UNSIGNED NOT NULL,
  `evaluator_user_id` INT(11) NOT NULL,
  `score` DECIMAL(7,2) NULL,
  `opinion` TEXT NULL,
  `staff_answers_json` LONGTEXT NULL,
  `submitted_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rsa_individual`
    (`community_id`, `application_id`, `stage_id`, `evaluator_user_id`),
  KEY `idx_rsa_stage` (`community_id`, `stage_id`, `application_id`),
  KEY `fk_rsa_evaluator` (`community_id`, `evaluator_user_id`),
  CONSTRAINT `fk_rsa_instance` FOREIGN KEY (`community_id`, `application_id`, `stage_id`)
    REFERENCES `recruitment_application_stages` (`community_id`, `application_id`, `stage_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_rsa_evaluator` FOREIGN KEY (`community_id`, `evaluator_user_id`)
    REFERENCES `user_community_status` (`community_id`, `user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_rsa_score` CHECK (`score` IS NULL OR (`score` >= 0 AND `score` <= 100)),
  CONSTRAINT `ck_rsa_answers_json` CHECK (
    `staff_answers_json` IS NULL OR JSON_VALID(`staff_answers_json`)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
