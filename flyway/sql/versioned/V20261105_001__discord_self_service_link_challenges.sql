-- OAuth-verified account recovery. No user IDs, Community data, XP,
-- economy or moderation history are merged or rewritten by this migration.
-- Store only a SHA-256 digest of the one-time browser ticket.
CREATE TABLE `user_discord_link_challenges` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `ticket_hash` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `requesting_user_id` INT NOT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'STARTED',
  `discord_user_id` BIGINT NULL,
  `discord_username` VARCHAR(32) NULL,
  `expires_at` DATETIME(6) NOT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `verified_at` DATETIME(6) NULL,
  `consumed_at` DATETIME(6) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_link_challenge_ticket` (`ticket_hash`),
  KEY `idx_discord_link_challenge_user` (`requesting_user_id`, `expires_at`),
  CONSTRAINT `fk_discord_link_challenge_user` FOREIGN KEY (`requesting_user_id`)
    REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ck_discord_link_challenge_status` CHECK
    (`status` IN ('STARTED', 'VERIFIED', 'CONSUMED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Expired tickets may be deleted by a scheduled retention job; no historical
-- permanent authorization is stored here. The permanent verified association
-- uses the pre-existing audited user_identity_links table (source SOCIAL).
