-- In-app recruitment exam incident events, private per tenant.
-- Event creation is only performed after an actual state transition in the API.
CREATE TABLE `recruitment_exam_incident_notices` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `community_id` INT(11) NOT NULL,
  `application_id` BIGINT(20) UNSIGNED NOT NULL,
  `stage_id` BIGINT(20) UNSIGNED NOT NULL,
  `attempt_id` BIGINT(20) UNSIGNED NOT NULL,
  `event_type` VARCHAR(20) NOT NULL,
  `occurred_at` DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
  `new_expires_at` DATETIME(6) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rein_tenant_id` (`community_id`,`id`),
  KEY `idx_rein_application` (`community_id`,`application_id`,`id`),
  KEY `idx_rein_attempt_fk`
    (`community_id`,`application_id`,`stage_id`,`attempt_id`),
  CONSTRAINT `fk_rein_attempt` FOREIGN KEY
    (`community_id`,`application_id`,`stage_id`,`attempt_id`)
    REFERENCES `recruitment_candidate_attempts`
      (`community_id`,`application_id`,`stage_id`,`id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_rein_type` CHECK
    (`event_type` IN ('BLOCKED','REINSTATED')),
  CONSTRAINT `ck_rein_expiry` CHECK
    ((`event_type`='BLOCKED' AND `new_expires_at` IS NULL)
     OR (`event_type`='REINSTATED' AND `new_expires_at` IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Read receipts are actor-specific: staff members never mark another staff's
-- notices as read, and candidate receipts cannot be forged across tenants.
CREATE TABLE `recruitment_exam_notice_reads` (
  `community_id` INT(11) NOT NULL,
  `notice_id` BIGINT(20) UNSIGNED NOT NULL,
  `user_id` INT(11) NOT NULL,
  `read_at` DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
  PRIMARY KEY (`community_id`,`notice_id`,`user_id`),
  KEY `fk_renr_user` (`community_id`,`user_id`),
  CONSTRAINT `fk_renr_notice` FOREIGN KEY (`community_id`,`notice_id`)
    REFERENCES `recruitment_exam_incident_notices` (`community_id`,`id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_renr_user` FOREIGN KEY (`community_id`,`user_id`)
    REFERENCES `user_community_status` (`community_id`,`user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
