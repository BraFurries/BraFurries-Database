-- Candidate attempt policies belong to frozen process versions. No changes to legacy rows.
-- API must only mutate policies on DRAFT versions and use the candidate's actual identity.
CREATE TABLE `recruitment_stage_attempt_policies` (
    `community_id` INT(11) NOT NULL,
    `process_version_id` BIGINT(20) UNSIGNED NOT NULL,
    `stage_id` BIGINT(20) UNSIGNED NOT NULL,
    `max_attempts` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `time_limit_seconds` INT(10) UNSIGNED NOT NULL,
    `deadline_at` DATETIME(6) NULL,
    `hard_deadline` TINYINT(1) NOT NULL DEFAULT 1,
    `max_focus_losses` TINYINT UNSIGNED NULL,
    `block_copy` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`community_id`,`process_version_id`,`stage_id`),
    CONSTRAINT `fk_rsap_stage` FOREIGN KEY (`community_id`,`process_version_id`,`stage_id`)
      REFERENCES `recruitment_stages` (`community_id`,`process_version_id`,`id`)
      ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_rsap_limits` CHECK (`max_attempts` BETWEEN 1 AND 5
      AND `time_limit_seconds` BETWEEN 60 AND 14400
      AND `hard_deadline` IN (0,1) AND `block_copy` IN (0,1)
      AND (`max_focus_losses` IS NULL OR `max_focus_losses` BETWEEN 1 AND 10))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- No mutable draft answers in this increment. Each attempt is a single, auditable submission.
CREATE TABLE `recruitment_candidate_attempts` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `application_id` BIGINT(20) UNSIGNED NOT NULL,
    `process_version_id` BIGINT(20) UNSIGNED NOT NULL,
    `stage_id` BIGINT(20) UNSIGNED NOT NULL,
    `attempt_number` TINYINT UNSIGNED NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'STARTED',
    `started_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `expires_at` DATETIME(6) NOT NULL,
    `submitted_at` DATETIME(6) NULL,
    `answers_json` LONGTEXT NULL,
    `focus_losses` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rca_number`
      (`community_id`,`application_id`,`stage_id`,`attempt_number`),
    KEY `idx_rca_stage` (`community_id`,`application_id`,`stage_id`,`status`),
    KEY `fk_rca_version` (`community_id`,`application_id`,`process_version_id`),
    KEY `fk_rca_policy` (`community_id`,`process_version_id`,`stage_id`),
    CONSTRAINT `fk_rca_application_stage` FOREIGN KEY
      (`community_id`,`application_id`,`stage_id`)
      REFERENCES `recruitment_application_stages`
      (`community_id`,`application_id`,`stage_id`)
      ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_rca_application_version` FOREIGN KEY
      (`community_id`,`application_id`,`process_version_id`)
      REFERENCES `recruitment_applications`
      (`community_id`,`id`,`process_version_id`)
      ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_rca_policy` FOREIGN KEY
      (`community_id`,`process_version_id`,`stage_id`)
      REFERENCES `recruitment_stage_attempt_policies`
      (`community_id`,`process_version_id`,`stage_id`)
      ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_rca_state` CHECK (`status` IN ('STARTED','SUBMITTED','EXPIRED','BLOCKED')),
    CONSTRAINT `ck_rca_attempt_no` CHECK (`attempt_number` BETWEEN 1 AND 5),
    CONSTRAINT `ck_rca_answers_json` CHECK
      (`answers_json` IS NULL OR JSON_VALID(`answers_json`)),
    CONSTRAINT `ck_rca_submission_state` CHECK
      ((`status`='SUBMITTED' AND `submitted_at` IS NOT NULL AND `answers_json` IS NOT NULL)
        OR (`status`<>'SUBMITTED' AND `submitted_at` IS NULL AND `answers_json` IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
