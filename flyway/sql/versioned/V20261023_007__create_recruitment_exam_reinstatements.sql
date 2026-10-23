-- One justified restoration per blocked attempt. The original attempt ID,
-- integrity signals and scores are never deleted. This is not a publication.
CREATE TABLE `recruitment_exam_reinstatements` (
  `community_id` INT(11) NOT NULL,
  `attempt_id` BIGINT(20) UNSIGNED NOT NULL,
  `application_id` BIGINT(20) UNSIGNED NOT NULL,
  `stage_id` BIGINT(20) UNSIGNED NOT NULL,
  `reviewed_by_user_id` INT(11) NOT NULL,
  `reason` VARCHAR(2000) NOT NULL,
  `previous_focus_losses` TINYINT UNSIGNED NOT NULL,
  `reinstated_at` DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
  `expires_at` DATETIME(6) NOT NULL,
  PRIMARY KEY (`community_id`,`attempt_id`),
  KEY `fk_rer_attempt`
    (`community_id`,`application_id`,`stage_id`,`attempt_id`),
  KEY `fk_rer_actor` (`community_id`,`reviewed_by_user_id`),
  CONSTRAINT `fk_rer_attempt` FOREIGN KEY
    (`community_id`,`application_id`,`stage_id`,`attempt_id`)
    REFERENCES `recruitment_candidate_attempts`
      (`community_id`,`application_id`,`stage_id`,`id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_rer_actor` FOREIGN KEY (`community_id`,`reviewed_by_user_id`)
    REFERENCES `user_community_status` (`community_id`,`user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_rer_reason` CHECK
    (CHAR_LENGTH(TRIM(`reason`)) BETWEEN 20 AND 2000),
  CONSTRAINT `ck_rer_previous_focus` CHECK
    (`previous_focus_losses` BETWEEN 1 AND 10),
  CONSTRAINT `ck_rer_expiry` CHECK (`expires_at` > `reinstated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
