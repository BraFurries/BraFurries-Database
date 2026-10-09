-- Tracks the Discord account that owns each persisted VIP custom role.
-- user_id remains the internal identity and existing cardinality is preserved.
-- The owner is nullable for legacy rows and is claimed safely by the runtime
-- when the live Discord role proves which linked account owns it.
ALTER TABLE `user_custom_roles`
    ADD COLUMN IF NOT EXISTS `owner_discord_user_id` BIGINT(20) NULL DEFAULT NULL,
    ADD INDEX IF NOT EXISTS `idx_user_custom_roles_guild_owner_discord`
        (`server_guild_id`, `owner_discord_user_id`);
