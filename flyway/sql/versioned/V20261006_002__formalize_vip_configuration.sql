-- Formalizes the guild-scoped VIP configuration already consumed by
-- BraFurries-Discord runtime DDL.
--
-- This is an additive migration:
-- - existing VIP role lists, prefixes and role ranges are preserved;
-- - existing custom-role rows and visual customization are preserved;
-- - no uniqueness/cardinality change is introduced for user_custom_roles;
-- - vip_allow_staff_colors defaults to false to preserve the current protection
--   against staff colors.

ALTER TABLE `config_server_settings`
    ADD COLUMN IF NOT EXISTS `vip_roles` TEXT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `vip_custom_role_prefix` VARCHAR(100) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `vip_role_division_start_id` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `vip_role_division_end_id` BIGINT(20) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `vip_allow_staff_colors` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `vip_reconcile_required` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `vip_reconcile_revision` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `staff_roles` TEXT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `staff_colors` TEXT NULL DEFAULT NULL;

ALTER TABLE `user_custom_roles`
    ADD COLUMN IF NOT EXISTS `color2` VARCHAR(32) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `role_id` BIGINT(20) NULL DEFAULT NULL;

ALTER TABLE `config_server_settings`
    ADD CONSTRAINT `ck_config_server_settings_vip_allow_staff_colors`
        CHECK (`vip_allow_staff_colors` IN (0, 1)),
    ADD CONSTRAINT `ck_config_server_settings_vip_reconcile_required`
        CHECK (`vip_reconcile_required` IN (0, 1));
