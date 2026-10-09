-- Supports event-driven VIP reconciliation.
-- Lookup shape:
--   WHERE server_guild_id = ? AND role_id IN (...)
--
-- Non-unique on purpose: preserves existing cardinality and legacy data.
ALTER TABLE `user_custom_roles`
    ADD INDEX IF NOT EXISTS `idx_user_custom_roles_guild_role`
        (`server_guild_id`, `role_id`);
