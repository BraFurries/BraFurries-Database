-- Expansion step for account-scoped VIP custom roles.
--
-- Production preflight must confirm before applying:
--   1. no NULL owner_discord_user_id rows;
--   2. no duplicate (server_guild_id, owner_discord_user_id) pairs;
--   3. every owner_discord_user_id resolves through user_discord.
--
-- user_id intentionally remains in this migration so old API/Coddy binaries
-- stay compatible during the rolling transition. It is removed only after all
-- consumers stop depending on it.

ALTER TABLE `user_custom_roles`
    MODIFY COLUMN `owner_discord_user_id` BIGINT(20) NOT NULL;

ALTER TABLE `user_custom_roles`
    DROP INDEX IF EXISTS `idx_user_custom_roles_guild_owner_discord`;

ALTER TABLE `user_custom_roles`
    ADD UNIQUE INDEX IF NOT EXISTS `uq_user_custom_roles_guild_owner_discord`
        (`server_guild_id`, `owner_discord_user_id`);
