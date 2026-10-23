-- Advisory browser signals: not proof of cheating. Events are per attempt and
-- idempotent, without storing page content, clipboard data, IP or personal text.
CREATE TABLE `recruitment_exam_integrity_events` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `community_id` INT(11) NOT NULL,
  `attempt_id` BIGINT(20) UNSIGNED NOT NULL,
  `event_uuid` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `event_type` VARCHAR(20) NOT NULL,
  `source` VARCHAR(20) NOT NULL,
  `occurred_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_reie_attempt_event` (`community_id`,`attempt_id`,`event_uuid`),
  KEY `idx_reie_attempt` (`community_id`,`attempt_id`,`occurred_at`),
  CONSTRAINT `fk_reie_attempt` FOREIGN KEY (`community_id`,`attempt_id`)
    REFERENCES `recruitment_candidate_attempts` (`community_id`,`id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_reie_event_type` CHECK
    (`event_type` IN ('FOCUS_LOST','COPY_PREVENTED')),
  CONSTRAINT `ck_reie_source` CHECK
    (`source` IN ('TAB_HIDDEN','WINDOW_BLUR','COPY','CUT','CONTEXT_MENU')),
  CONSTRAINT `ck_reie_type_source` CHECK (
    (`event_type`='FOCUS_LOST' AND `source` IN ('TAB_HIDDEN','WINDOW_BLUR'))
    OR (`event_type`='COPY_PREVENTED' AND `source` IN ('COPY','CUT','CONTEXT_MENU'))
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
