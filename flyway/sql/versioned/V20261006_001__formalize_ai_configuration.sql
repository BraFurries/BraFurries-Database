-- Formalizes the guild-scoped AI configuration already consumed by
-- BraFurries-Discord. This is an additive migration: existing token ciphertext,
-- model, enablement and allowed-channel rows are preserved.
--
-- Existing legacy columns has_gpt_enabled and gpt_model are intentionally not
-- modified here. They are established fields in config_server_settings and
-- changing their type/default during this expand step would add unnecessary
-- compatibility risk.
--
-- allowed_feature_channels was already formalized by
-- V20260929_001__formalize_bump_configuration.sql and is reused with
-- feature_key = 'ai_responses'; no parallel AI-channel table is introduced.

ALTER TABLE `config_server_settings`
    ADD COLUMN IF NOT EXISTS `ai_openai_token_encrypted` TEXT NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `ai_openai_token_updated_at` DATETIME(6) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `ai_channel_limit_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `ai_admin_channel_bypass_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `ai_admin_user_ids` TEXT NULL DEFAULT NULL;

-- Do not backfill ai_openai_token_updated_at for legacy ciphertext. A migration
-- timestamp would falsely claim when the credential itself was rotated. Legacy
-- rows therefore remain tokenConfigured=true / tokenUpdatedAt=null until the
-- next validated rotation.

ALTER TABLE `config_server_settings`
    ADD CONSTRAINT `ck_config_server_settings_ai_channel_limit_enabled`
        CHECK (`ai_channel_limit_enabled` IN (0, 1)),
    ADD CONSTRAINT `ck_config_server_settings_ai_admin_channel_bypass_enabled`
        CHECK (`ai_admin_channel_bypass_enabled` IN (0, 1));
