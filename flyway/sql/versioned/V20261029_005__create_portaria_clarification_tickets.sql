-- Portaria exceptional clarification ticket (opt-in, disabled by default).
-- API owns configuration and its authorization; Coddy owns operational ticket state.
-- One record per submitted form. Reopening/duplicates must never create
-- multiple rooms; decisions on the form remain independent of ticket creation.
-- Staff identity is a Discord snowflake: an authorized Discord moderator need
-- not have a corresponding BraFurries Web user account.

ALTER TABLE `portaria_base_config`
  ADD COLUMN `clarification_tickets_enabled` TINYINT(1) NOT NULL DEFAULT 0
    AFTER `portaria_enabled`,
  ADD COLUMN `clarification_ticket_category_id` BIGINT(20) NULL DEFAULT NULL
    AFTER `clarification_tickets_enabled`,
  ADD CONSTRAINT `ck_pbc_clarification_tickets_enabled`
    CHECK (`clarification_tickets_enabled` IN (0, 1)),
  ADD CONSTRAINT `ck_pbc_clarification_category_when_enabled`
    CHECK (`clarification_tickets_enabled` = 0
      OR `clarification_ticket_category_id` IS NOT NULL);

-- Composite parent keys explicitly bind the submission and the Discord guild
-- to the same Community. Do not rely on independent FK existence checks.
ALTER TABLE `form_submissions`
  ADD UNIQUE KEY `uq_form_submissions_id_guild` (`id`, `guild_id`);

ALTER TABLE `community_discord`
  ADD UNIQUE KEY `uq_community_discord_community_guild` (`community_id`, `guild_id`);

CREATE TABLE `portaria_clarification_tickets` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `community_id` INT(11) NOT NULL,
  `guild_id` BIGINT(20) NOT NULL,
  `submission_id` INT(11) NOT NULL,
  `applicant_discord_user_id` BIGINT(20) NOT NULL,
  `requested_by_discord_user_id` BIGINT(20) NOT NULL,
  `reason` VARCHAR(1024) NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'REQUESTED',
  `discord_channel_id` BIGINT(20) NULL,
  `requested_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `opened_at` DATETIME(6) NULL,
  `closed_at` DATETIME(6) NULL,
  `closed_by_discord_user_id` BIGINT(20) NULL,
  `close_reason` VARCHAR(1024) NULL,
  `last_error_code` VARCHAR(64) NULL,
  `version` BIGINT(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  -- Exact one ticket per submission, across retries and restarts.
  UNIQUE KEY `uq_pct_community_submission` (`community_id`, `submission_id`),
  UNIQUE KEY `uq_pct_guild_channel` (`guild_id`, `discord_channel_id`),
  KEY `idx_pct_community_status` (`community_id`, `status`, `requested_at`),
  KEY `idx_pct_guild_status` (`guild_id`, `status`, `requested_at`),
  CONSTRAINT `fk_pct_community_guild` FOREIGN KEY (`community_id`, `guild_id`)
    REFERENCES `community_discord` (`community_id`, `guild_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_pct_submission_guild` FOREIGN KEY (`submission_id`, `guild_id`)
    REFERENCES `form_submissions` (`id`, `guild_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `ck_pct_state` CHECK (
    `status` IN ('REQUESTED', 'OPENING', 'OPEN', 'CLOSING', 'CLOSED', 'FAILED')
  ),
  CONSTRAINT `ck_pct_reason` CHECK (
    CHAR_LENGTH(TRIM(`reason`)) BETWEEN 10 AND 1024
  ),
  CONSTRAINT `ck_pct_open` CHECK (
    (`status` IN ('OPEN','CLOSING','CLOSED') AND `discord_channel_id` IS NOT NULL)
    OR `status` IN ('REQUESTED','OPENING','FAILED')
  ),
  CONSTRAINT `ck_pct_closure` CHECK (
    (`status`='CLOSED' AND `closed_at` IS NOT NULL
      AND `closed_by_discord_user_id` IS NOT NULL
      AND `close_reason` IS NOT NULL)
    OR `status` <> 'CLOSED'
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
