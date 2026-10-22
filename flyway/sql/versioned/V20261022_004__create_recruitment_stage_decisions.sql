-- Recruitment V1: one explicit, immutable administrative decision per candidate/stage.
-- No automated evaluation, vote quorum or candidate-facing publication in this migration.
-- Data belongs to the same Community through composite foreign keys.
CREATE TABLE `recruitment_stage_decisions` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `community_id` INT(11) NOT NULL,
  `application_id` BIGINT(20) UNSIGNED NOT NULL,
  `stage_id` BIGINT(20) UNSIGNED NOT NULL,
  `decided_by_user_id` INT(11) NOT NULL,
  `outcome` VARCHAR(12) NOT NULL,
  `reason` VARCHAR(2000) NULL,
  `decided_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rsd_single_stage_decision`
    (`community_id`, `application_id`, `stage_id`),
  KEY `idx_rsd_actor` (`community_id`, `decided_by_user_id`),
  CONSTRAINT `fk_rsd_application_stage`
    FOREIGN KEY (`community_id`, `application_id`, `stage_id`)
    REFERENCES `recruitment_application_stages`
      (`community_id`, `application_id`, `stage_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_rsd_actor`
    FOREIGN KEY (`community_id`, `decided_by_user_id`)
    REFERENCES `user_community_status` (`community_id`, `user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_rsd_outcome` CHECK (`outcome` IN ('APPROVE','REJECT')),
  CONSTRAINT `ck_rsd_rejection_reason` CHECK (
    `outcome` <> 'REJECT' OR
    (`reason` IS NOT NULL AND CHAR_LENGTH(TRIM(`reason`)) BETWEEN 10 AND 2000)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
