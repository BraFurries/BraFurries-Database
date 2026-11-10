-- Track the most recently observed bot installation/removal per Discord guild.
-- Timestamps are UTC; do not infer historical join/leave times from legacy
-- active flags or migration execution time.
ALTER TABLE `community_discord`
    ADD COLUMN `last_bot_joined_at` DATETIME(6) DEFAULT NULL,
    ADD COLUMN `last_bot_left_at` DATETIME(6) DEFAULT NULL,
    ADD KEY `idx_cd_last_bot_joined_at` (`last_bot_joined_at`),
    ADD KEY `idx_cd_last_bot_left_at` (`last_bot_left_at`);
