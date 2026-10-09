CREATE TABLE `bump_monthly_reward_runs` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `server_guild_id` BIGINT NOT NULL,
    `period_start` DATE NOT NULL,
    `period_end` DATE NOT NULL,
    `source_channel_id` BIGINT NOT NULL,
    `reward_role_id` BIGINT NULL,
    `reward_days_1` INT NOT NULL DEFAULT 0,
    `reward_days_2` INT NOT NULL DEFAULT 0,
    `reward_days_3` INT NOT NULL DEFAULT 0,
    `reward_coins_1` INT NOT NULL DEFAULT 0,
    `reward_coins_2` INT NOT NULL DEFAULT 0,
    `reward_coins_3` INT NOT NULL DEFAULT 0,
    `ranking_prepared_at` DATETIME NULL,
    `attempt_count` INT NOT NULL DEFAULT 0,
    `last_attempt_at` DATETIME NULL,
    `completed_at` DATETIME NULL,
    `last_error` VARCHAR(512) NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bump_monthly_reward_runs_guild_period` (`server_guild_id`, `period_start`),
    KEY `idx_bump_monthly_reward_runs_guild_completed` (`server_guild_id`, `completed_at`),
    KEY `idx_bump_monthly_reward_runs_period_start` (`period_start`),
    CONSTRAINT `ck_bump_monthly_reward_runs_calendar_period`
        CHECK (
            DAYOFMONTH(`period_start`) = 1
            AND `period_end` = DATE_ADD(`period_start`, INTERVAL 1 MONTH)
        ),
    CONSTRAINT `fk_bump_monthly_reward_runs_guild`
        FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`)
        ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `bump_monthly_reward_grants` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `run_id` BIGINT NOT NULL,
    `discord_user_id` BIGINT NOT NULL,
    `rank_position` TINYINT UNSIGNED NOT NULL,
    `bump_count` INT UNSIGNED NOT NULL,
    `first_bump_at` DATETIME NULL,
    `coins_amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `role_id` BIGINT NULL,
    `role_days` INT UNSIGNED NOT NULL DEFAULT 0,
    `role_expires_at` DATETIME NULL,
    `coins_applied_at` DATETIME NULL,
    `role_applied_at` DATETIME NULL,
    `role_skipped_at` DATETIME NULL,
    `notification_attempted_at` DATETIME NULL,
    `notification_sent_at` DATETIME NULL,
    `last_error` VARCHAR(512) NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bump_monthly_reward_grants_run_rank` (`run_id`, `rank_position`),
    UNIQUE KEY `uq_bump_monthly_reward_grants_run_user` (`run_id`, `discord_user_id`),
    KEY `idx_bump_monthly_reward_grants_run` (`run_id`),
    CONSTRAINT `ck_bump_monthly_reward_grants_rank_position`
        CHECK (`rank_position` BETWEEN 1 AND 3),
    CONSTRAINT `fk_bump_monthly_reward_grants_run`
        FOREIGN KEY (`run_id`) REFERENCES `bump_monthly_reward_runs` (`id`)
        ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
