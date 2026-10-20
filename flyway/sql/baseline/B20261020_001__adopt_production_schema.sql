-- Flyway canonical structural baseline at version 20261020.001.

-- Derived from an owner-provided, schema-only MariaDB structural export;

-- sanitized: no database name/USE, production data, identities, or AUTO_INCREMENT counters.

-- Deliberate CREATE TABLE (not IF NOT EXISTS): fail fast on wrong/non-empty targets.

-- Dependency-ordered: cross-table foreign keys are checked, not disabled.

-- Preserve legacy objects, including tables without PRIMARY KEY, as exported.

-- Fresh databases only. Existing production requires separate explicit Flyway `baseline`

-- after physical schema fingerprint, backup/restore, and operator authorization.



CREATE TABLE `active_call_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `voice_channel_id` bigint(20) NOT NULL,
  `log_message_id` bigint(20) DEFAULT NULL,
  `payload_json` longtext DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_active_call_logs_channel` (`server_guild_id`,`voice_channel_id`),
  KEY `idx_active_call_logs_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `allowed_feature_channels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `feature_key` varchar(100) NOT NULL,
  `channel_id` bigint(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_allowed_feature_channels` (`server_guild_id`,`feature_key`,`channel_id`),
  KEY `idx_allowed_feature_channels_lookup` (`server_guild_id`,`feature_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `api_clients` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `client_key` varchar(100) NOT NULL,
  `active` bit(1) NOT NULL DEFAULT b'1',
  `type` enum('internal','partner','bot','service') NOT NULL DEFAULT 'partner',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `client_key` (`client_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `api_permissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_api_permissions_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `api_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_api_roles_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_discord` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `original_name` varchar(255) DEFAULT NULL,
  `backup_type` varchar(20) NOT NULL DEFAULT 'normal',
  `created_by_discord_user_id` bigint(20) DEFAULT NULL,
  `idempotency_key` varchar(96) DEFAULT NULL,
  `creation_audited_at` datetime(6) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_backup_discord_guild_idempotency` (`guild_id`,`idempotency_key`),
  KEY `idx_backup_discord_guild_type` (`guild_id`,`backup_type`,`id`),
  KEY `idx_backup_discord_guild` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_guild_locks` (
  `guild_id` bigint(20) NOT NULL,
  `lock_token` varchar(96) NOT NULL,
  `operation_type` varchar(32) NOT NULL,
  `operation_id` bigint(20) DEFAULT NULL,
  `expires_at` datetime(6) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`guild_id`),
  KEY `idx_backup_guild_locks_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_operation_steps` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `operation_kind` varchar(20) NOT NULL,
  `operation_id` bigint(20) NOT NULL,
  `step_code` varchar(96) NOT NULL,
  `step_status` varchar(20) NOT NULL,
  `message` varchar(512) NOT NULL,
  `progress_current` int(11) NOT NULL DEFAULT 0,
  `progress_total` int(11) NOT NULL DEFAULT 0,
  `detail_json` longtext DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT utc_timestamp(6),
  PRIMARY KEY (`id`),
  KEY `idx_backup_operation_steps_operation` (`guild_id`,`operation_kind`,`operation_id`,`id`),
  CONSTRAINT `ck_backup_operation_steps_kind` CHECK (`operation_kind` in ('SNAPSHOT','RESTORE')),
  CONSTRAINT `ck_backup_operation_steps_status` CHECK (`step_status` in ('PENDING','RUNNING','SUCCEEDED','SKIPPED','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_server_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `max_normal_backups` int(11) NOT NULL DEFAULT 1,
  `max_periodic_backups` int(11) NOT NULL DEFAULT 1,
  `periodic_backups_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `periodicity_minutes` int(11) NOT NULL DEFAULT 10080,
  `periodicity_frequency` varchar(10) NOT NULL DEFAULT 'weekly',
  `bot_removed_at` datetime(6) DEFAULT NULL,
  `purge_after` datetime(6) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_backup_server_settings_guild` (`guild_id`),
  KEY `idx_backup_server_settings_purge_after` (`purge_after`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `bot_sensitive_permission_whitelist` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `actor_id` bigint(20) NOT NULL,
  `actor_type` varchar(10) NOT NULL DEFAULT 'bot',
  `permission_name` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bot_sensitive_permission_whitelist` (`server_guild_id`,`actor_id`,`actor_type`,`permission_name`),
  KEY `idx_bot_sensitive_permission_whitelist_lookup` (`server_guild_id`,`actor_id`,`actor_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `commands` (
  `id` int(16) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `cooldown` time(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_boss_attack_cooldown` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `cooldown_until` bigint(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_community_boss_cooldown` (`guild_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_boss_contribution` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `total_damage` bigint(20) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_community_boss_contribution` (`guild_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_boss_event` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `boss_name` varchar(120) NOT NULL DEFAULT 'Boss',
  `max_hp` int(11) NOT NULL,
  `current_hp` int(11) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `attack_cooldown_seconds` int(11) NOT NULL DEFAULT 30,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `finished_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_community_boss_guild` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_expedition` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `started_at` bigint(20) NOT NULL,
  `ends_at` bigint(20) NOT NULL,
  `participants_json` longtext NOT NULL,
  `finalized_at` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_community_expedition_guild` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `form_flows` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `type` varchar(50) NOT NULL,
  `server_guild_id` bigint(20) DEFAULT NULL,
  `target_channel_id` bigint(20) NOT NULL,
  `approved_target_channel_id` bigint(20) DEFAULT NULL,
  `rejected_target_channel_id` bigint(20) DEFAULT NULL,
  `rejection_feedback_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_form_flows_type` (`type`),
  KEY `idx_form_flows_target_channel` (`target_channel_id`),
  KEY `idx_form_flows_server_guild_id` (`server_guild_id`),
  KEY `idx_form_flows_server_name` (`server_guild_id`,`name`),
  KEY `idx_form_flows_server_type` (`server_guild_id`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `locale` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `locale_abbrev` varchar(8) NOT NULL,
  `locale_name` varchar(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `locale_abbrev` (`locale_abbrev`),
  UNIQUE KEY `locale_name` (`locale_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `portaria_account_release` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `access_mode` varchar(20) NOT NULL DEFAULT 'completo',
  `requires_form` tinyint(1) NOT NULL DEFAULT 1,
  `released_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_portaria_account_release` (`server_guild_id`,`user_id`),
  KEY `idx_portaria_account_release_lookup` (`server_guild_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `portaria_base_config` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `acesso_provisorio_role_id` bigint(20) DEFAULT NULL,
  `visitante_role_id` bigint(20) DEFAULT NULL,
  `maior_18_role_id` bigint(20) DEFAULT NULL,
  `menor_18_role_id` bigint(20) DEFAULT NULL,
  `aprovacao_acesso_provisorio_ativo` tinyint(1) NOT NULL DEFAULT 1,
  `aprovacao_acesso_provisorio_duracao_dias` int(11) NOT NULL DEFAULT 15,
  `formulario_portaria_ativo` tinyint(1) NOT NULL DEFAULT 1,
  `idade_minima_conta_ficha_ativa` tinyint(1) NOT NULL DEFAULT 0,
  `idade_minima_conta_ficha_dias` int(11) NOT NULL DEFAULT 0,
  `idade_minima_conta_acesso_provisorio_ativa` tinyint(1) NOT NULL DEFAULT 0,
  `idade_minima_conta_acesso_provisorio_dias` int(11) NOT NULL DEFAULT 30,
  `idade_minima_entrada_servidor_ativa` tinyint(1) NOT NULL DEFAULT 0,
  `idade_minima_entrada_servidor_anos` int(11) NOT NULL DEFAULT 0,
  `idade_minima_conta_dias` int(11) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `portaria_enabled` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_portaria_base_config_guild` (`server_guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `portaria_bypasses` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `bypass_type` varchar(16) NOT NULL,
  `discord_user_id` bigint(20) DEFAULT NULL,
  `invite_code` varchar(128) DEFAULT NULL,
  `access_mode` varchar(20) DEFAULT NULL,
  `requires_form` tinyint(1) DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `expires_at` datetime(6) DEFAULT NULL,
  `expired_at` datetime(6) DEFAULT NULL,
  `removed_at` datetime(6) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_portaria_bypass_account` (`server_guild_id`,`bypass_type`,`discord_user_id`),
  UNIQUE KEY `uq_portaria_bypass_invite` (`server_guild_id`,`bypass_type`,`invite_code`),
  KEY `idx_portaria_bypass_guild_active` (`server_guild_id`,`active`),
  KEY `idx_portaria_bypass_expiry` (`active`,`expires_at`),
  CONSTRAINT `ck_portaria_bypass_type` CHECK (`bypass_type` in ('invite','account')),
  CONSTRAINT `ck_portaria_bypass_active` CHECK (`active` in (0,1)),
  CONSTRAINT `ck_portaria_bypass_target` CHECK (`bypass_type` = 'account' and `discord_user_id` is not null and `invite_code` is null and `access_mode` in ('provisorio','completo') and `requires_form` in (0,1) or `bypass_type` = 'invite' and `discord_user_id` is null and `invite_code` is not null and `access_mode` is null and `requires_form` is null)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  `applied_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `telegram_event_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `channel_name` varchar(32) NOT NULL DEFAULT '',
  `message_id` int(11) NOT NULL DEFAULT 0,
  `active` bit(1) NOT NULL DEFAULT b'1',
  `send_new_message` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `display_name` varchar(100) DEFAULT NULL,
  `username` varchar(32) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `password_hash` varchar(256) DEFAULT NULL,
  `first_access` bit(1) NOT NULL DEFAULT b'1',
  `profile_image_key` varchar(512) DEFAULT NULL,
  `profile_image_url` varchar(1024) DEFAULT NULL,
  `profile_image_content_type` varchar(100) DEFAULT NULL,
  `profile_image_updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `voice_sessions` (
  `server_guild_id` bigint(20) NOT NULL,
  `discord_user_id` bigint(20) NOT NULL,
  `voice_channel_id` bigint(20) NOT NULL,
  `started_at` datetime NOT NULL,
  `last_tick_at` datetime NOT NULL,
  `is_eligible` tinyint(1) NOT NULL DEFAULT 0,
  `is_self_muted` tinyint(1) NOT NULL DEFAULT 0,
  `is_self_deafened` tinyint(1) NOT NULL DEFAULT 0,
  `is_server_muted` tinyint(1) NOT NULL DEFAULT 0,
  `is_server_deafened` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`server_guild_id`,`discord_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `voice_xp_audit_log` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `discord_user_id` bigint(20) NOT NULL,
  `voice_channel_id` bigint(20) DEFAULT NULL,
  `event_type` varchar(64) NOT NULL,
  `xp_amount` int(11) NOT NULL DEFAULT 0,
  `eligible_seconds` int(11) NOT NULL DEFAULT 0,
  `ineligible_seconds` int(11) NOT NULL DEFAULT 0,
  `meta_json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`meta_json`)),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_voice_xp_audit_guild_day` (`server_guild_id`,`created_at`),
  KEY `idx_voice_xp_audit_user_day` (`server_guild_id`,`discord_user_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `voice_xp_daily_metrics` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `metric_day` date NOT NULL,
  `server_guild_id` bigint(20) NOT NULL,
  `modality` varchar(32) NOT NULL,
  `voice_channel_id` bigint(20) DEFAULT NULL,
  `total_xp` bigint(20) NOT NULL DEFAULT 0,
  `grants_count` bigint(20) NOT NULL DEFAULT 0,
  `blocks_count` bigint(20) NOT NULL DEFAULT 0,
  `eligible_seconds` bigint(20) NOT NULL DEFAULT 0,
  `ineligible_seconds` bigint(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_voice_xp_daily_metrics` (`metric_day`,`server_guild_id`,`modality`,`voice_channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `api_client_permissions` (
  `client_id` int(11) NOT NULL,
  `permission` varchar(100) NOT NULL,
  PRIMARY KEY (`client_id`,`permission`),
  CONSTRAINT `fk_api_client_permissions_client` FOREIGN KEY (`client_id`) REFERENCES `api_clients` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `api_role_permissions` (
  `role_id` int(11) NOT NULL,
  `permission_id` int(11) NOT NULL,
  PRIMARY KEY (`role_id`,`permission_id`),
  KEY `FK_api_role_permissions_permission` (`permission_id`),
  CONSTRAINT `FK_api_role_permissions_permission` FOREIGN KEY (`permission_id`) REFERENCES `api_permissions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_api_role_permissions_role` FOREIGN KEY (`role_id`) REFERENCES `api_roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `api_user_roles` (
  `user_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`,`role_id`),
  KEY `FK_api_user_roles_role` (`role_id`),
  CONSTRAINT `FK_api_user_roles_role` FOREIGN KEY (`role_id`) REFERENCES `api_roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_api_user_roles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_channels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `backup_id` int(11) NOT NULL DEFAULT 0,
  `discord_id` bigint(20) NOT NULL,
  `parent_id` bigint(20) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `type` int(11) NOT NULL,
  `position` int(11) DEFAULT NULL,
  `topic` text DEFAULT NULL,
  `nsfw` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_backup_channels_backup` (`backup_id`),
  CONSTRAINT `FK_backup_channels_backup_discord` FOREIGN KEY (`backup_id`) REFERENCES `backup_discord` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_restore_operations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `backup_id` int(11) NOT NULL,
  `operation_key` varchar(96) NOT NULL,
  `scope` varchar(20) NOT NULL,
  `actor_discord_user_id` bigint(20) NOT NULL,
  `actor_user_id` int(11) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'PENDING',
  `decision_json` longtext DEFAULT NULL,
  `result_json` longtext DEFAULT NULL,
  `error_code` varchar(96) DEFAULT NULL,
  `progress_current` int(11) NOT NULL DEFAULT 0,
  `progress_total` int(11) NOT NULL DEFAULT 0,
  `current_step` varchar(96) DEFAULT NULL,
  `requested_audited_at` datetime(6) DEFAULT NULL,
  `completion_audited_at` datetime(6) DEFAULT NULL,
  `started_at` datetime(6) DEFAULT NULL,
  `finished_at` datetime(6) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_backup_restore_guild_operation_key` (`guild_id`,`operation_key`),
  KEY `idx_backup_restore_guild_status` (`guild_id`,`status`,`id`),
  KEY `idx_backup_restore_backup` (`guild_id`,`backup_id`),
  KEY `fk_backup_restore_actor` (`actor_user_id`),
  CONSTRAINT `fk_backup_restore_actor` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `ck_backup_restore_scope` CHECK (`scope` in ('full','roles','channels','permissions')),
  CONSTRAINT `ck_backup_restore_status` CHECK (`status` in ('PENDING','RUNNING','SUCCEEDED','PARTIAL','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `backup_id` int(11) NOT NULL,
  `discord_id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `color` int(11) DEFAULT NULL,
  `permissions` bigint(20) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `hoist` tinyint(1) DEFAULT NULL,
  `mentionable` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_backup_roles_backup` (`backup_id`),
  CONSTRAINT `fk_backup_roles_backup` FOREIGN KEY (`backup_id`) REFERENCES `backup_discord` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_snapshot_operations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `operation_key` varchar(96) NOT NULL,
  `backup_type` varchar(20) NOT NULL,
  `requested_name` varchar(255) NOT NULL,
  `actor_discord_user_id` bigint(20) DEFAULT NULL,
  `actor_user_id` int(11) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'PENDING',
  `backup_id` int(11) DEFAULT NULL,
  `progress_current` int(11) NOT NULL DEFAULT 0,
  `progress_total` int(11) NOT NULL DEFAULT 0,
  `current_step` varchar(96) DEFAULT NULL,
  `result_json` longtext DEFAULT NULL,
  `error_code` varchar(96) DEFAULT NULL,
  `requested_audited_at` datetime(6) DEFAULT NULL,
  `completion_audited_at` datetime(6) DEFAULT NULL,
  `started_at` datetime(6) DEFAULT NULL,
  `finished_at` datetime(6) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_backup_snapshot_guild_operation_key` (`guild_id`,`operation_key`),
  KEY `idx_backup_snapshot_guild_status` (`guild_id`,`status`,`id`),
  KEY `idx_backup_snapshot_backup` (`guild_id`,`backup_id`),
  KEY `fk_backup_snapshot_actor` (`actor_user_id`),
  CONSTRAINT `fk_backup_snapshot_actor` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `ck_backup_snapshot_type` CHECK (`backup_type` in ('normal','periodic')),
  CONSTRAINT `ck_backup_snapshot_status` CHECK (`status` in ('PENDING','RUNNING','SUCCEEDED','PARTIAL','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `communities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `owner_user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `idx_communities_owner_user` (`owner_user_id`),
  CONSTRAINT `fk_communities_owner_user` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `config_command_uses` (
  `user_id` int(32) NOT NULL,
  `command_id` int(11) NOT NULL,
  `dtm_last_usage` datetime NOT NULL,
  KEY `FK_command_uses_users` (`user_id`),
  KEY `FK_command_uses_commands` (`command_id`),
  CONSTRAINT `FK_command_uses_commands` FOREIGN KEY (`command_id`) REFERENCES `commands` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_command_uses_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_themes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `guild_id` bigint(20) NOT NULL,
  `name` varchar(120) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `icon_action` varchar(12) NOT NULL DEFAULT 'UNCHANGED',
  `icon_asset_key` varchar(512) DEFAULT NULL,
  `icon_asset_content_type` varchar(100) DEFAULT NULL,
  `icon_asset_sha256` char(64) DEFAULT NULL,
  `icon_asset_size_bytes` bigint(20) DEFAULT NULL,
  `banner_action` varchar(12) NOT NULL DEFAULT 'UNCHANGED',
  `banner_asset_key` varchar(512) DEFAULT NULL,
  `banner_asset_content_type` varchar(100) DEFAULT NULL,
  `banner_asset_sha256` char(64) DEFAULT NULL,
  `banner_asset_size_bytes` bigint(20) DEFAULT NULL,
  `created_by_discord_user_id` bigint(20) NOT NULL,
  `created_by_user_id` int(11) DEFAULT NULL,
  `deleted_at` datetime(6) DEFAULT NULL,
  `active_name` varchar(120) GENERATED ALWAYS AS (case when `deleted_at` is null then `name` else NULL end) STORED,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_themes_guild_id` (`guild_id`,`id`),
  UNIQUE KEY `uq_discord_themes_guild_active_name` (`guild_id`,`active_name`),
  KEY `idx_discord_themes_guild_deleted` (`guild_id`,`deleted_at`,`id`),
  KEY `fk_discord_themes_created_by_user` (`created_by_user_id`),
  CONSTRAINT `fk_discord_themes_created_by_user` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `ck_discord_themes_icon_action` CHECK (`icon_action` in ('UNCHANGED','SET','REMOVE')),
  CONSTRAINT `ck_discord_themes_banner_action` CHECK (`banner_action` in ('UNCHANGED','SET','REMOVE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `events` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host_user_id` int(11) NOT NULL,
  `locale_id` int(11) NOT NULL,
  `event_name` varchar(64) NOT NULL,
  `description` varchar(512) DEFAULT NULL,
  `city` varchar(32) NOT NULL,
  `address` varchar(256) NOT NULL,
  `point_name` varchar(64) DEFAULT NULL,
  `price` double NOT NULL,
  `max_price` double DEFAULT NULL,
  `price_confirmed` bit(1) NOT NULL DEFAULT b'0',
  `group_chat_link` varchar(256) DEFAULT NULL,
  `website` varchar(64) DEFAULT NULL,
  `ticket_url` varchar(256) DEFAULT NULL,
  `event_logo_url` varchar(256) DEFAULT NULL,
  `out_of_tickets` bit(1) NOT NULL DEFAULT b'0',
  `sales_ended` bit(1) NOT NULL DEFAULT b'0',
  `approved` bit(1) DEFAULT NULL,
  `is_event` bit(1) NOT NULL DEFAULT b'0',
  `partner_event` bit(1) NOT NULL DEFAULT b'0',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `event_name` (`event_name`),
  KEY `events_host_user_id_users_id` (`host_user_id`),
  KEY `events_locale_id_locale_id` (`locale_id`),
  KEY `idx_events_dashboard_type_partner` (`approved`,`is_event`,`partner_event`,`id`),
  KEY `idx_events_host_approved` (`host_user_id`,`approved`,`id`),
  CONSTRAINT `events_host_user_id_users_id` FOREIGN KEY (`host_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `events_locale_id_locale_id` FOREIGN KEY (`locale_id`) REFERENCES `locale` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `form_published_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flow_id` int(11) NOT NULL,
  `message_id` bigint(20) NOT NULL,
  `channel_id` bigint(20) NOT NULL,
  `guild_id` bigint(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_form_published_message` (`message_id`),
  KEY `idx_form_published_flow` (`flow_id`),
  CONSTRAINT `fk_form_published_flow` FOREIGN KEY (`flow_id`) REFERENCES `form_flows` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `form_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flow_id` int(11) NOT NULL,
  `question_text` text NOT NULL,
  `placeholder_text` varchar(100) DEFAULT NULL,
  `position` int(11) NOT NULL,
  `required` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_form_questions_flow` (`flow_id`),
  KEY `idx_form_questions_position` (`position`),
  CONSTRAINT `fk_form_questions_flow` FOREIGN KEY (`flow_id`) REFERENCES `form_flows` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `form_submissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flow_id` int(11) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `guild_id` bigint(20) NOT NULL,
  `channel_id` bigint(20) NOT NULL,
  `message_id` bigint(20) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_form_submissions_flow` (`flow_id`),
  KEY `idx_form_submissions_status` (`status`),
  KEY `idx_form_submissions_message` (`message_id`),
  CONSTRAINT `fk_form_submissions_flow` FOREIGN KEY (`flow_id`) REFERENCES `form_flows` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `invites` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `token` varchar(64) NOT NULL,
  `type` varchar(64) NOT NULL,
  `status` varchar(32) NOT NULL,
  `requested_by_user_id` int(11) NOT NULL,
  `target_user_id` int(11) NOT NULL,
  `reason` varchar(512) NOT NULL,
  `created_at` datetime NOT NULL,
  `responded_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_invites_token` (`token`),
  KEY `idx_invites_target_status` (`target_user_id`,`status`),
  KEY `fk_invites_requested_by` (`requested_by_user_id`),
  CONSTRAINT `fk_invites_requested_by` FOREIGN KEY (`requested_by_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_invites_target` FOREIGN KEY (`target_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `minigame_scores` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `server_guild_id` bigint(20) NOT NULL,
  `game_name` varchar(40) NOT NULL,
  `points` int(11) NOT NULL DEFAULT 0,
  `won` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_minigame_scores_guild_week` (`server_guild_id`,`created_at`),
  KEY `idx_minigame_scores_user` (`user_id`),
  CONSTRAINT `fk_minigame_scores_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_birthday` (
  `user_id` int(11) NOT NULL,
  `birth_date` date NOT NULL,
  `post_informed_date` date DEFAULT NULL,
  `verified` bit(1) NOT NULL,
  `registered` bit(1) NOT NULL,
  `registered_at` datetime NOT NULL DEFAULT current_timestamp(),
  `18_plus` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `user_birthday_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_discord` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `discord_user_id` bigint(20) NOT NULL DEFAULT 0,
  `username` varchar(32) NOT NULL,
  `display_name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `discord_user_id` (`discord_user_id`),
  KEY `discord_user_user_id_users_id` (`user_id`),
  CONSTRAINT `discord_user_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_identity_links` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_a_id` int(11) NOT NULL,
  `user_b_id` int(11) NOT NULL,
  `status` varchar(16) NOT NULL DEFAULT 'CONFIRMED',
  `link_source` varchar(32) NOT NULL DEFAULT 'ADMIN',
  `reason` varchar(500) DEFAULT NULL,
  `linked_by_user_id` int(11) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `revoked_at` datetime(6) DEFAULT NULL,
  `revoked_by_user_id` int(11) DEFAULT NULL,
  `revocation_reason` varchar(500) DEFAULT NULL,
  `active_user_low_id` int(11) GENERATED ALWAYS AS (case when `revoked_at` is null then least(`user_a_id`,`user_b_id`) else NULL end) STORED,
  `active_user_high_id` int(11) GENERATED ALWAYS AS (case when `revoked_at` is null then greatest(`user_a_id`,`user_b_id`) else NULL end) STORED,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_identity_links_active_pair` (`active_user_low_id`,`active_user_high_id`),
  KEY `idx_user_identity_linked` (`user_b_id`),
  KEY `idx_user_identity_linked_by` (`linked_by_user_id`),
  KEY `idx_user_identity_revoked_by` (`revoked_by_user_id`),
  KEY `idx_user_identity_links_user_a_active` (`user_a_id`,`revoked_at`),
  KEY `idx_user_identity_links_user_b_active` (`user_b_id`,`revoked_at`),
  CONSTRAINT `fk_user_identity_linked_by` FOREIGN KEY (`linked_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_user_identity_links_user_a` FOREIGN KEY (`user_a_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_user_identity_links_user_b` FOREIGN KEY (`user_b_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_user_identity_revoked_by` FOREIGN KEY (`revoked_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_user_identity_link_status` CHECK (`status` in ('CONFIRMED','SUSPECTED')),
  CONSTRAINT `chk_user_identity_link_source` CHECK (`link_source` in ('ADMIN','LEGACY_SPLIT','SOCIAL')),
  CONSTRAINT `chk_user_identity_links_distinct_users` CHECK (`user_a_id` <> `user_b_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_locale` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `locale_id` int(11) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `user_id` (`user_id`),
  KEY `user_locale_locale_id_locale_id` (`locale_id`),
  KEY `id` (`id`),
  CONSTRAINT `user_locale_locale_id_locale_id` FOREIGN KEY (`locale_id`) REFERENCES `locale` (`id`),
  CONSTRAINT `user_locale_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_notes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `note` varchar(512) NOT NULL DEFAULT '0',
  `author_user_id` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_note` (`user_id`,`note`,`author_user_id`) USING BTREE,
  KEY `FK_user_notes_users_2` (`author_user_id`),
  CONSTRAINT `FK_user_notes_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_user_notes_users_2` FOREIGN KEY (`author_user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_patreon` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `display_name` varchar(32) NOT NULL,
  `patreon_user_id` bigint(20) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  UNIQUE KEY `patreon_user_id` (`patreon_user_id`),
  CONSTRAINT `patreon_user_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_permissions` (
  `user_id` int(11) NOT NULL,
  `admin` bit(1) NOT NULL DEFAULT b'0',
  `developer` bit(1) NOT NULL DEFAULT b'0',
  `create_events` bit(1) NOT NULL DEFAULT b'0',
  `edit_events` bit(1) NOT NULL DEFAULT b'0',
  `create_users` bit(1) NOT NULL DEFAULT b'0',
  `edit_users` bit(1) NOT NULL DEFAULT b'0',
  KEY `FK_user_permissions_users` (`user_id`),
  CONSTRAINT `FK_user_permissions_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_refresh_tokens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `token` varchar(128) NOT NULL,
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `revoked_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `fk_user_refresh_tokens_user` (`user_id`),
  CONSTRAINT `fk_user_refresh_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_telegram` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `telegram_user_id` int(11) NOT NULL,
  `username` varchar(32) NOT NULL,
  `display_name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  UNIQUE KEY `username` (`username`),
  CONSTRAINT `telegram_user_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_tokens` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `type` varchar(40) NOT NULL,
  `token` varchar(128) NOT NULL,
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `used_at` timestamp NULL DEFAULT NULL,
  `revoked_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_tokens_token` (`token`),
  KEY `idx_user_tokens_user_type` (`user_id`,`type`),
  KEY `idx_user_tokens_type_expires_at` (`type`,`expires_at`),
  CONSTRAINT `fk_user_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `backup_overwrites` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `channel_id` int(11) NOT NULL DEFAULT 0,
  `role_name` varchar(255) NOT NULL,
  `target_type` varchar(24) NOT NULL DEFAULT 'ROLE',
  `target_discord_id` bigint(20) DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  `allow_bits` bigint(20) DEFAULT NULL,
  `deny_bits` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_backup_overwrites_channel` (`channel_id`),
  KEY `idx_backup_overwrites_role` (`role_id`),
  KEY `idx_backup_overwrites_target_discord` (`target_discord_id`),
  CONSTRAINT `fk_backup_overwrites_channel` FOREIGN KEY (`channel_id`) REFERENCES `backup_channels` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_backup_overwrites_role` FOREIGN KEY (`role_id`) REFERENCES `backup_roles` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ck_backup_overwrites_target_type` CHECK (`target_type` in ('ROLE','EVERYONE','MANAGED_ROLE')),
  CONSTRAINT `ck_backup_overwrites_target_shape` CHECK (`target_type` = 'ROLE' and `role_id` is not null or `target_type` in ('EVERYONE','MANAGED_ROLE') and `role_id` is null and `target_discord_id` is not null)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_audit_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `actor_user_id` int(11) NOT NULL,
  `action` varchar(64) NOT NULL,
  `target_type` varchar(64) DEFAULT NULL,
  `target_id` varchar(128) DEFAULT NULL,
  `metadata` longtext DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`id`),
  KEY `idx_cal_community_created` (`community_id`,`created_at`,`id`),
  KEY `idx_cal_actor_created` (`actor_user_id`,`created_at`),
  CONSTRAINT `fk_cal_actor` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_cal_community` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_discord` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `guild_id` bigint(20) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `discord_admin_id` bigint(20) DEFAULT NULL,
  `users_quantity` int(11) NOT NULL DEFAULT 0,
  `membership_sync_state` varchar(32) NOT NULL DEFAULT 'RECONCILIATION_REQUIRED',
  `last_full_reconciliation_at` datetime(6) DEFAULT NULL,
  `last_membership_event_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `community_id` (`community_id`),
  UNIQUE KEY `guild_id` (`guild_id`),
  KEY `idx_community_discord_active_users` (`active`,`users_quantity`),
  KEY `idx_community_discord_admin_guild` (`discord_admin_id`,`guild_id`),
  CONSTRAINT `discord_servers_community_id_communities_id` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`),
  CONSTRAINT `ck_community_discord_membership_sync_state` CHECK (`membership_sync_state` in ('RECONCILIATION_REQUIRED','RECONCILING','HEALTHY','DEGRADED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_network_sync_runs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `network_type` varchar(32) NOT NULL,
  `external_network_id` bigint(20) NOT NULL,
  `trigger` varchar(32) NOT NULL,
  `status` varchar(16) NOT NULL DEFAULT 'QUEUED',
  `started_at` datetime(6) DEFAULT NULL,
  `completed_at` datetime(6) DEFAULT NULL,
  `observed_members` int(10) unsigned DEFAULT NULL,
  `updated_members` int(10) unsigned DEFAULT NULL,
  `error_code` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_cnsr_community_network` (`community_id`,`network_type`,`external_network_id`),
  KEY `idx_cnsr_community_status_started` (`community_id`,`status`,`started_at`),
  KEY `idx_cnsr_network_status_id` (`network_type`,`status`,`id`),
  CONSTRAINT `fk_cnsr_community` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`),
  CONSTRAINT `ck_cnsr_status` CHECK (`status` in ('QUEUED','RUNNING','SUCCESS','FAILED')),
  CONSTRAINT `ck_cnsr_observed_members` CHECK (`observed_members` is null or `observed_members` >= 0),
  CONSTRAINT `ck_cnsr_updated_members` CHECK (`updated_members` is null or `updated_members` >= 0),
  CONSTRAINT `ck_cnsr_trigger` CHECK (`trigger` in ('GUILD_JOIN','STARTUP','PERIODIC','MANUAL','OWNERSHIP_CHANGE','DRIFT','RECOVERY'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_store` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL DEFAULT 0,
  `owner_user_id` int(11) DEFAULT 0,
  `item_name` char(50) NOT NULL DEFAULT '0',
  `item_price` int(11) NOT NULL DEFAULT 0,
  `item_image_url` varchar(256) DEFAULT NULL,
  `quantity_available` int(11) DEFAULT 0,
  `quantity_total` int(11) DEFAULT 0,
  `allow_multiple` bit(1) NOT NULL DEFAULT b'0',
  `is_service` bit(1) NOT NULL DEFAULT b'0',
  `duration` bigint(20) DEFAULT NULL COMMENT 'duração do item em segundos',
  PRIMARY KEY (`id`),
  KEY `FK_community_store_communities` (`community_id`),
  KEY `FK_community_store_users` (`owner_user_id`),
  CONSTRAINT `FK_community_store_communities` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_community_store_users` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_team_demands` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ctd_community_id_id` (`community_id`,`id`),
  KEY `idx_ctd_community_name` (`community_id`,`name`),
  CONSTRAINT `fk_ctd_community` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_team_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `parent_role_id` int(11) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ctr_community_id_id` (`community_id`,`id`),
  KEY `idx_ctr_community_active` (`community_id`,`active`),
  KEY `idx_ctr_parent` (`community_id`,`parent_role_id`),
  CONSTRAINT `fk_ctr_community` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`),
  CONSTRAINT `fk_ctr_parent_same_community` FOREIGN KEY (`community_id`, `parent_role_id`) REFERENCES `community_team_roles` (`community_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_telegram` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `community_id` (`community_id`),
  CONSTRAINT `telegram_group_community_id_communities_id` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `config_warnings_settings` (
  `community_id` int(11) NOT NULL,
  `warnings_expire` bit(1) NOT NULL DEFAULT b'0',
  `mute_on_warn` bit(1) NOT NULL DEFAULT b'0',
  `warnings_limit` int(11) NOT NULL,
  `expiration_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`community_id`) USING BTREE,
  UNIQUE KEY `community_id` (`community_id`) USING BTREE,
  CONSTRAINT `FK_warnings_settings_communities` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_applications` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `theme_id` bigint(20) NOT NULL,
  `guild_id` bigint(20) NOT NULL,
  `actor_discord_user_id` bigint(20) NOT NULL,
  `actor_user_id` int(11) DEFAULT NULL,
  `status` varchar(24) NOT NULL DEFAULT 'APPLYING',
  `frozen_definition_json` longtext NOT NULL,
  `applied_at` datetime(6) DEFAULT NULL,
  `restored_at` datetime(6) DEFAULT NULL,
  `error_summary` varchar(512) DEFAULT NULL,
  `rollback_assets_cleaned_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_theme_app_guild_id` (`guild_id`,`id`),
  KEY `idx_discord_theme_app_guild_status` (`guild_id`,`status`,`id`),
  KEY `idx_discord_theme_app_theme` (`theme_id`,`id`),
  KEY `fk_discord_theme_app_theme` (`guild_id`,`theme_id`),
  KEY `fk_discord_theme_app_actor_user` (`actor_user_id`),
  CONSTRAINT `fk_discord_theme_app_actor_user` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_discord_theme_app_theme` FOREIGN KEY (`guild_id`, `theme_id`) REFERENCES `discord_themes` (`guild_id`, `id`),
  CONSTRAINT `ck_discord_theme_app_status` CHECK (`status` in ('APPLYING','ACTIVE','APPLY_PARTIAL','FAILED','RESTORING','RESTORED','RESTORE_PARTIAL'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_assets` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `theme_id` bigint(20) NOT NULL,
  `guild_id` bigint(20) NOT NULL,
  `asset_type` varchar(12) NOT NULL,
  `storage_key` varchar(512) NOT NULL,
  `content_type` varchar(100) NOT NULL,
  `sha256` char(64) NOT NULL,
  `size_bytes` bigint(20) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_theme_asset_key` (`storage_key`),
  KEY `idx_discord_theme_assets_theme` (`theme_id`,`asset_type`,`id`),
  KEY `idx_discord_theme_assets_guild` (`guild_id`,`theme_id`,`id`),
  CONSTRAINT `fk_discord_theme_asset_theme` FOREIGN KEY (`guild_id`, `theme_id`) REFERENCES `discord_themes` (`guild_id`, `id`) ON DELETE CASCADE,
  CONSTRAINT `ck_discord_theme_asset_type` CHECK (`asset_type` in ('ICON','BANNER')),
  CONSTRAINT `ck_discord_theme_asset_size` CHECK (`size_bytes` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_resource_changes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `theme_id` bigint(20) NOT NULL,
  `resource_type` varchar(16) NOT NULL,
  `resource_discord_id` bigint(20) NOT NULL,
  `target_name` varchar(100) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_theme_resource` (`theme_id`,`resource_type`,`resource_discord_id`),
  KEY `idx_discord_theme_resource_theme` (`theme_id`,`id`),
  CONSTRAINT `fk_discord_theme_resource_theme` FOREIGN KEY (`theme_id`) REFERENCES `discord_themes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ck_discord_theme_resource_type` CHECK (`resource_type` in ('CHANNEL','CATEGORY','ROLE')),
  CONSTRAINT `ck_discord_theme_resource_id` CHECK (`resource_discord_id` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `event_scheduling` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `event_id` int(20) NOT NULL,
  `starting_datetime` datetime NOT NULL,
  `ending_datetime` datetime NOT NULL,
  `gcalendar_id` varchar(255) NOT NULL,
  `gcal_event_id` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `gcal_id` (`gcal_event_id`) USING BTREE,
  KEY `idx_event_scheduling_event_id` (`event_id`),
  KEY `idx_event_scheduling_starting_datetime` (`starting_datetime`),
  KEY `idx_event_scheduling_ending_datetime` (`ending_datetime`),
  KEY `idx_event_scheduling_event_end_id` (`event_id`,`ending_datetime`,`id`),
  KEY `idx_event_scheduling_event_start_end_id` (`event_id`,`starting_datetime`,`ending_datetime`,`id`),
  KEY `idx_event_scheduling_latest` (`event_id`,`ending_datetime`,`id`),
  KEY `idx_event_scheduling_upcoming` (`starting_datetime`,`event_id`,`ending_datetime`,`id`),
  CONSTRAINT `FK_event_scheduling_events` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `chk_scheduling_valid_period` CHECK (`ending_datetime` > `starting_datetime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `event_staffs` (
  `event_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `cargo` varchar(50) DEFAULT NULL,
  `mng_agenda` bit(1) NOT NULL DEFAULT b'0',
  `edit_event` bit(1) NOT NULL DEFAULT b'0',
  `mng_staff` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`event_id`,`user_id`),
  KEY `idx_event_staffs_user_event` (`user_id`,`event_id`),
  CONSTRAINT `staffs_event_id_events_id` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`),
  CONSTRAINT `staffs_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `event_transfer_logs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `invite_id` bigint(20) NOT NULL,
  `event_id` int(11) NOT NULL,
  `actor_user_id` int(11) NOT NULL,
  `from_user_id` int(11) NOT NULL,
  `to_user_id` int(11) NOT NULL,
  `action` varchar(32) NOT NULL,
  `reason` varchar(512) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_event_transfer_logs_invite` (`invite_id`),
  KEY `idx_event_transfer_logs_event` (`event_id`),
  KEY `fk_event_transfer_logs_actor` (`actor_user_id`),
  KEY `fk_event_transfer_logs_from_user` (`from_user_id`),
  KEY `fk_event_transfer_logs_to_user` (`to_user_id`),
  CONSTRAINT `fk_event_transfer_logs_actor` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_event_transfer_logs_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`),
  CONSTRAINT `fk_event_transfer_logs_from_user` FOREIGN KEY (`from_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_event_transfer_logs_invite` FOREIGN KEY (`invite_id`) REFERENCES `invites` (`id`),
  CONSTRAINT `fk_event_transfer_logs_to_user` FOREIGN KEY (`to_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `event_transfer_requests` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `invite_id` bigint(20) NOT NULL,
  `event_id` int(11) NOT NULL,
  `original_owner_user_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_event_transfer_requests_invite` (`invite_id`),
  KEY `idx_event_transfer_requests_event` (`event_id`),
  KEY `fk_event_transfer_requests_original_owner` (`original_owner_user_id`),
  CONSTRAINT `fk_event_transfer_requests_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`),
  CONSTRAINT `fk_event_transfer_requests_invite` FOREIGN KEY (`invite_id`) REFERENCES `invites` (`id`),
  CONSTRAINT `fk_event_transfer_requests_original_owner` FOREIGN KEY (`original_owner_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `form_decisions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `submission_id` int(11) NOT NULL,
  `decision` varchar(20) NOT NULL,
  `decided_by` bigint(20) NOT NULL,
  `decided_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_form_decisions_submission` (`submission_id`),
  KEY `idx_form_decisions_decision` (`decision`),
  CONSTRAINT `fk_form_decisions_submission` FOREIGN KEY (`submission_id`) REFERENCES `form_submissions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `partners` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `community_id` int(11) DEFAULT NULL,
  `name` varchar(64) NOT NULL,
  `slug` varchar(96) DEFAULT NULL,
  `category` varchar(32) NOT NULL DEFAULT 'community',
  `status` varchar(32) NOT NULL DEFAULT 'active',
  `description` varchar(2048) DEFAULT NULL,
  `image_url` varchar(1024) DEFAULT NULL,
  `website_url` varchar(1024) DEFAULT NULL,
  `contact_name` varchar(128) DEFAULT NULL,
  `contact_email` varchar(255) DEFAULT NULL,
  `representative_user_id` int(11) DEFAULT NULL,
  `secret` varchar(128) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `uk_partners_slug` (`slug`),
  KEY `FK_partners_communities` (`community_id`),
  KEY `idx_partners_status_category` (`status`,`category`),
  KEY `idx_partners_representative_user` (`representative_user_id`),
  CONSTRAINT `FK_partners_communities` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `chk_partners_category` CHECK (`category` in ('community','creator','event','meet','discord_server','brand','other')),
  CONSTRAINT `chk_partners_status` CHECK (`status` in ('pending','active','suspended'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `community_id` int(11) NOT NULL,
  `date` date DEFAULT current_timestamp(),
  `reason` varchar(256) NOT NULL,
  `can_appeal` bit(1) NOT NULL DEFAULT b'0',
  `valid_until` date DEFAULT NULL,
  `applied_by` int(11) DEFAULT NULL,
  `registered_at` datetime NOT NULL DEFAULT current_timestamp(),
  `revoked_at` datetime DEFAULT NULL COMMENT 'Data/hora em que o ban foi revogado',
  `revoked_by` int(11) DEFAULT NULL COMMENT 'users.id do responsável pela revogação',
  `revocation_reason` varchar(512) DEFAULT NULL COMMENT 'Motivo informado para a revogação',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_ban` (`community_id`,`date`,`reason`),
  KEY `banned_user` (`user_id`),
  KEY `ban_author` (`applied_by`),
  KEY `fk_user_bans_revoked_by` (`revoked_by`),
  CONSTRAINT `FK_user_bans_communities` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ban_author` FOREIGN KEY (`applied_by`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `banned_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_bans_revoked_by` FOREIGN KEY (`revoked_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_community_status` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `community_id` int(11) NOT NULL,
  `member_since` datetime NOT NULL,
  `last_join_date` datetime DEFAULT NULL,
  `is_present` tinyint(1) DEFAULT NULL COMMENT 'Presença atual na comunidade: 1=presente, 0=ausente, NULL=não reconciliado',
  `left_at` datetime DEFAULT NULL COMMENT 'Data da saída atual; NULL quando presente ou ainda não reconciliado',
  `approved` bit(1) NOT NULL DEFAULT b'0',
  `approved_at` datetime DEFAULT NULL,
  `invite_link_used` varchar(255) DEFAULT NULL,
  `invited_by` varchar(255) DEFAULT NULL,
  `is_vip` bit(1) NOT NULL DEFAULT b'0',
  `is_partner` bit(1) NOT NULL DEFAULT b'0',
  `banned` bit(1) NOT NULL DEFAULT b'0',
  `last_message_ts` timestamp NULL DEFAULT NULL,
  `last_bump_ts` timestamp NULL DEFAULT NULL,
  `birthday_mentionable` tinyint(1) NOT NULL DEFAULT 0,
  `approval_required` tinyint(1) DEFAULT NULL,
  `display_name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_community_status_community_user` (`community_id`,`user_id`),
  KEY `id` (`id`),
  KEY `FK_user_community_status_users` (`user_id`),
  CONSTRAINT `FK_user_community_status_communities` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_user_community_status_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_warnings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `community_id` int(11) NOT NULL,
  `date` date NOT NULL,
  `reason` varchar(1024) NOT NULL,
  `expired` bit(1) NOT NULL DEFAULT b'0',
  `applied_by` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `unique_warning` (`user_id`,`community_id`,`date`,`reason`) USING HASH,
  KEY `warns_user_id_users_id` (`user_id`),
  KEY `FK_warns_communities` (`community_id`),
  KEY `FK_user_warnings_users` (`applied_by`),
  CONSTRAINT `FK_user_warnings_users` FOREIGN KEY (`applied_by`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_warns_communities` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `warns_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `blacklisted_games` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL DEFAULT 0,
  `game_name` varchar(50) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `FK_blacklisted_games_discord_servers` (`server_guild_id`),
  CONSTRAINT `FK_blacklisted_games_discord_servers` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `bump_monthly_reward_runs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `source_channel_id` bigint(20) NOT NULL,
  `reward_role_id` bigint(20) DEFAULT NULL,
  `reward_days_1` int(11) NOT NULL DEFAULT 0,
  `reward_days_2` int(11) NOT NULL DEFAULT 0,
  `reward_days_3` int(11) NOT NULL DEFAULT 0,
  `reward_coins_1` int(11) NOT NULL DEFAULT 0,
  `reward_coins_2` int(11) NOT NULL DEFAULT 0,
  `reward_coins_3` int(11) NOT NULL DEFAULT 0,
  `ranking_prepared_at` datetime DEFAULT NULL,
  `attempt_count` int(11) NOT NULL DEFAULT 0,
  `last_attempt_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `last_error` varchar(512) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bump_monthly_reward_runs_guild_period` (`server_guild_id`,`period_start`),
  KEY `idx_bump_monthly_reward_runs_guild_completed` (`server_guild_id`,`completed_at`),
  KEY `idx_bump_monthly_reward_runs_period_start` (`period_start`),
  CONSTRAINT `fk_bump_monthly_reward_runs_guild` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ck_bump_monthly_reward_runs_calendar_period` CHECK (dayofmonth(`period_start`) = 1 and `period_end` = `period_start` + interval 1 month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_member_notes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `author_user_id` int(11) NOT NULL,
  `updated_by_user_id` int(11) NOT NULL,
  `content` text NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  `archived_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_cmn_member_archive_created` (`community_id`,`user_id`,`archived_at`,`created_at`,`id`),
  KEY `idx_cmn_author_created` (`author_user_id`,`created_at`),
  KEY `idx_cmn_updated_by` (`updated_by_user_id`),
  CONSTRAINT `fk_cmn_author` FOREIGN KEY (`author_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_cmn_member_same_community` FOREIGN KEY (`community_id`, `user_id`) REFERENCES `user_community_status` (`community_id`, `user_id`),
  CONSTRAINT `fk_cmn_updated_by` FOREIGN KEY (`updated_by_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_network_member_events` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `network_type` varchar(32) NOT NULL,
  `external_network_id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `event_type` varchar(32) NOT NULL,
  `occurred_at` datetime(6) NOT NULL,
  `observed_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `source` varchar(32) NOT NULL,
  `sync_run_id` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_cnme_network_user_time` (`network_type`,`external_network_id`,`user_id`,`occurred_at`,`id`),
  KEY `idx_cnme_community_user_time` (`community_id`,`user_id`,`occurred_at`,`id`),
  KEY `idx_cnme_sync_run` (`sync_run_id`),
  KEY `fk_cnme_user` (`user_id`),
  CONSTRAINT `fk_cnme_community` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`),
  CONSTRAINT `fk_cnme_sync_run` FOREIGN KEY (`sync_run_id`) REFERENCES `community_network_sync_runs` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_cnme_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_network_member_status` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `network_type` varchar(32) NOT NULL,
  `external_network_id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `is_present` tinyint(1) NOT NULL DEFAULT 0,
  `first_known_join_at` datetime(6) DEFAULT NULL,
  `first_known_join_source` varchar(32) DEFAULT NULL,
  `last_join_at` datetime(6) DEFAULT NULL,
  `last_join_source` varchar(32) DEFAULT NULL,
  `current_presence_since` datetime(6) DEFAULT NULL,
  `left_at` datetime(6) DEFAULT NULL,
  `last_observed_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `last_sync_run_id` bigint(20) unsigned DEFAULT NULL,
  `approval_required` tinyint(1) DEFAULT NULL,
  `approved` tinyint(1) DEFAULT NULL,
  `approved_at` datetime(6) DEFAULT NULL,
  `display_name` varchar(100) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cnms_network_user` (`network_type`,`external_network_id`,`user_id`),
  KEY `idx_cnms_community_user_present` (`community_id`,`user_id`,`is_present`),
  KEY `idx_cnms_network_present_user` (`network_type`,`external_network_id`,`is_present`,`user_id`),
  KEY `idx_cnms_user_network` (`user_id`,`network_type`,`external_network_id`),
  KEY `idx_cnms_network_sync` (`network_type`,`external_network_id`,`last_sync_run_id`,`is_present`),
  KEY `fk_cnms_last_sync_run` (`last_sync_run_id`),
  CONSTRAINT `fk_cnms_community` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`),
  CONSTRAINT `fk_cnms_last_sync_run` FOREIGN KEY (`last_sync_run_id`) REFERENCES `community_network_sync_runs` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_cnms_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_team_demand_roles` (
  `community_id` int(11) NOT NULL,
  `demand_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`community_id`,`demand_id`,`role_id`),
  KEY `idx_ctdr_community_role` (`community_id`,`role_id`),
  CONSTRAINT `fk_ctdr_demand_same_community` FOREIGN KEY (`community_id`, `demand_id`) REFERENCES `community_team_demands` (`community_id`, `id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ctdr_role_same_community` FOREIGN KEY (`community_id`, `role_id`) REFERENCES `community_team_roles` (`community_id`, `id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_team_role_assignments` (
  `community_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`community_id`,`role_id`,`user_id`),
  KEY `idx_ctra_community_user` (`community_id`,`user_id`),
  CONSTRAINT `fk_ctra_member_same_community` FOREIGN KEY (`community_id`, `user_id`) REFERENCES `user_community_status` (`community_id`, `user_id`),
  CONSTRAINT `fk_ctra_role_same_community` FOREIGN KEY (`community_id`, `role_id`) REFERENCES `community_team_roles` (`community_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_team_role_capabilities` (
  `community_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `capability` varchar(64) NOT NULL,
  `granted_by_user_id` int(11) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`community_id`,`role_id`,`capability`),
  KEY `idx_ctrc_grantor` (`granted_by_user_id`,`created_at`),
  CONSTRAINT `fk_ctrc_grantor` FOREIGN KEY (`granted_by_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_ctrc_role_same_community` FOREIGN KEY (`community_id`, `role_id`) REFERENCES `community_team_roles` (`community_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `community_user_capability_grants` (
  `community_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `capability` varchar(64) NOT NULL,
  `granted_by_user_id` int(11) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`community_id`,`user_id`,`capability`),
  KEY `idx_cucg_grantor` (`granted_by_user_id`,`created_at`),
  CONSTRAINT `fk_cucg_grantor` FOREIGN KEY (`granted_by_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_cucg_member_same_community` FOREIGN KEY (`community_id`, `user_id`) REFERENCES `user_community_status` (`community_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `config_economy` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `currency_name` varchar(16) NOT NULL,
  `currency_prefix` varchar(16) NOT NULL,
  `message_points_per_day` int(11) DEFAULT NULL,
  `message_points` int(11) DEFAULT NULL,
  `daily_max_points` int(11) DEFAULT NULL,
  `birthday_points` int(11) DEFAULT NULL,
  `bump_points` int(11) DEFAULT NULL,
  `transfer_tax` double DEFAULT NULL,
  `bet_odds_3x` double DEFAULT NULL,
  `bet_odds_2x` double DEFAULT NULL,
  `bet_odds_1x` double DEFAULT NULL,
  `bump_reward_enabled` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `server_guild_id` (`server_guild_id`),
  CONSTRAINT `economy_config_server_guild_id_discord_servers_guild_id` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `config_levels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `clear_on_exit` tinyint(1) NOT NULL DEFAULT 0,
  `levelup_warning` tinyint(1) NOT NULL DEFAULT 0,
  `levelup_warning_channel` bigint(64) DEFAULT NULL,
  `level_up_message` text NOT NULL,
  `multiplier` decimal(20,3) DEFAULT NULL COMMENT 'multiplicador aplicado (bom para eventos)',
  `phase1_k` decimal(20,3) NOT NULL DEFAULT 45.000 COMMENT 'valor que multiplica x (kx^p +bx )',
  `phase1_p` decimal(20,3) NOT NULL DEFAULT 2.000 COMMENT 'valor que x é elevado (kx^p +bx )',
  `phase1_b` decimal(20,3) NOT NULL DEFAULT 0.000 COMMENT 'coeficiente linear da reta (kx^p +bx )',
  `daily_combo` int(11) DEFAULT NULL COMMENT 'qtd. de atividades necessárias para alcançar um combo',
  `combo_multiplier` decimal(20,3) DEFAULT NULL COMMENT 'multiplicador por combo',
  `xp_base_per_min` int(11) NOT NULL DEFAULT 2,
  `voice_social_bonus_pct` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `voice_social_bonus_min_humans` int(11) NOT NULL DEFAULT 2,
  `voice_diminishing_window1_minutes` int(11) NOT NULL DEFAULT 60,
  `voice_diminishing_window2_minutes` int(11) NOT NULL DEFAULT 120,
  `voice_diminishing_factor2` decimal(8,4) NOT NULL DEFAULT 0.6000,
  `voice_diminishing_factor3` decimal(8,4) NOT NULL DEFAULT 0.3000,
  `voice_daily_cap_xp` int(11) NOT NULL DEFAULT 600,
  `text_daily_cap_xp` int(11) NOT NULL DEFAULT 300,
  `global_daily_cap_xp` int(11) NOT NULL DEFAULT 900,
  `text_xp_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `voice_xp_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `text_xp_base_min` int(11) NOT NULL DEFAULT 8,
  `text_xp_base_max` int(11) NOT NULL DEFAULT 16,
  `text_xp_cooldown_min_seconds` int(11) NOT NULL DEFAULT 30,
  `text_xp_cooldown_max_seconds` int(11) NOT NULL DEFAULT 60,
  `level_reconcile_required` tinyint(1) NOT NULL DEFAULT 0,
  `level_reconcile_requested_at` datetime(6) DEFAULT NULL,
  `level_reconciled_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `server_guild_id` (`server_guild_id`),
  CONSTRAINT `levels_config_server_guild_id_discord_servers_guild_id` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`),
  CONSTRAINT `ck_config_levels_text_xp_enabled` CHECK (`text_xp_enabled` in (0,1)),
  CONSTRAINT `ck_config_levels_voice_xp_enabled` CHECK (`voice_xp_enabled` in (0,1)),
  CONSTRAINT `ck_config_levels_level_reconcile_required` CHECK (`level_reconcile_required` in (0,1)),
  CONSTRAINT `ck_config_levels_text_xp_range` CHECK (`text_xp_base_min` >= 0 and `text_xp_base_max` >= `text_xp_base_min`),
  CONSTRAINT `ck_config_levels_text_cooldown_range` CHECK (`text_xp_cooldown_min_seconds` >= 0 and `text_xp_cooldown_max_seconds` >= `text_xp_cooldown_min_seconds`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `config_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL DEFAULT 0,
  `type` varchar(50) NOT NULL DEFAULT '',
  `enabled` bit(1) NOT NULL DEFAULT b'0',
  `log_channel` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_config_logs_community_discord` (`server_guild_id`),
  CONSTRAINT `FK_config_logs_community_discord` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `config_server_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `has_levels` bit(1) NOT NULL DEFAULT b'0',
  `has_economy` bit(1) NOT NULL DEFAULT b'0',
  `has_role_division` bit(1) NOT NULL DEFAULT b'0',
  `has_gpt_enabled` bit(1) NOT NULL DEFAULT b'0',
  `gpt_model` varchar(32) NOT NULL DEFAULT 'gpt-5-nano',
  `general_chat_id` bigint(20) NOT NULL DEFAULT 0,
  `staff_roles` text DEFAULT NULL,
  `vip_role_division_start_id` bigint(20) DEFAULT NULL,
  `vip_role_division_end_id` bigint(20) DEFAULT NULL,
  `birthday_channel_id` bigint(20) DEFAULT NULL,
  `collab_moderation_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `collab_moderation_emoji` varchar(64) DEFAULT NULL,
  `collab_moderation_min_reactions` int(11) NOT NULL DEFAULT 3,
  `bump_warn_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `bump_warn_disboard_channel_id` bigint(20) DEFAULT NULL,
  `bump_warn_target_channel_id` bigint(20) DEFAULT NULL,
  `bump_warn_messages` text DEFAULT NULL,
  `bump_warn_next_at` datetime DEFAULT NULL,
  `bump_warn_last_bump_at` datetime DEFAULT NULL,
  `bump_reward_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `bump_reward_temp_role_id` bigint(20) DEFAULT NULL,
  `bump_reward_role_minutes` int(11) NOT NULL DEFAULT 0,
  `bump_reward_coins` int(11) NOT NULL DEFAULT 0,
  `bump_reward_message` text DEFAULT NULL,
  `bump_monthly_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `bump_monthly_disboard_channel_id` bigint(20) DEFAULT NULL,
  `bump_monthly_reward_role_id` bigint(20) DEFAULT NULL,
  `bump_monthly_reward_days_1` int(11) NOT NULL DEFAULT 21,
  `bump_monthly_reward_days_2` int(11) NOT NULL DEFAULT 14,
  `bump_monthly_reward_days_3` int(11) NOT NULL DEFAULT 7,
  `bump_monthly_reward_coins_1` int(11) NOT NULL DEFAULT 0,
  `bump_monthly_reward_coins_2` int(11) NOT NULL DEFAULT 0,
  `bump_monthly_reward_coins_3` int(11) NOT NULL DEFAULT 0,
  `auto_join_roles_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `auto_join_role_ids` text DEFAULT NULL,
  `vip_roles` text DEFAULT NULL,
  `vip_custom_role_prefix` varchar(100) DEFAULT NULL,
  `hashtag_role_mentions_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `hashtag_role_mentions_channel_ids` text DEFAULT NULL,
  `hashtag_role_mentions_author_role_id` bigint(20) DEFAULT NULL,
  `hashtag_role_mentions_map` text DEFAULT NULL,
  `thread_owner_only_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `thread_owner_only_forum_channel_ids` text DEFAULT NULL,
  `trending_presence_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `ai_openai_token_encrypted` text DEFAULT NULL,
  `ai_channel_limit_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `ai_admin_channel_bypass_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `ai_admin_user_ids` text DEFAULT NULL,
  `ai_openai_token_updated_at` datetime(6) DEFAULT NULL,
  `vip_allow_staff_colors` tinyint(1) NOT NULL DEFAULT 0,
  `vip_reconcile_required` tinyint(1) NOT NULL DEFAULT 0,
  `vip_reconcile_revision` bigint(20) unsigned NOT NULL DEFAULT 0,
  `staff_colors` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `server_guild_id` (`server_guild_id`),
  KEY `id` (`id`),
  CONSTRAINT `FK_server_settings_discord_servers` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ck_config_server_settings_ai_channel_limit_enabled` CHECK (`ai_channel_limit_enabled` in (0,1)),
  CONSTRAINT `ck_config_server_settings_ai_admin_channel_bypass_enabled` CHECK (`ai_admin_channel_bypass_enabled` in (0,1)),
  CONSTRAINT `ck_config_server_settings_vip_allow_staff_colors` CHECK (`vip_allow_staff_colors` in (0,1)),
  CONSTRAINT `ck_config_server_settings_vip_reconcile_required` CHECK (`vip_reconcile_required` in (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_role_division` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `division_name` varchar(110) NOT NULL,
  `division_position` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `division_name` (`division_name`),
  UNIQUE KEY `division_position` (`division_position`),
  KEY `role_division_server_guild_id_discord_servers_guild_id` (`server_guild_id`),
  CONSTRAINT `role_division_server_guild_id_discord_servers_guild_id` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_server_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL DEFAULT 0,
  `birthday` varchar(1024) DEFAULT NULL,
  `bump` varchar(1024) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `FK__discord_servers` (`server_guild_id`),
  CONSTRAINT `FK__discord_servers` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_active_guilds` (
  `guild_id` bigint(20) NOT NULL,
  `application_id` bigint(20) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`guild_id`),
  UNIQUE KEY `uq_discord_theme_active_application` (`application_id`),
  KEY `fk_discord_theme_active_application` (`guild_id`,`application_id`),
  CONSTRAINT `fk_discord_theme_active_application` FOREIGN KEY (`guild_id`, `application_id`) REFERENCES `discord_theme_applications` (`guild_id`, `id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_application_snapshots` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `application_id` bigint(20) NOT NULL,
  `resource_type` varchar(20) NOT NULL,
  `resource_discord_id` bigint(20) NOT NULL DEFAULT 0,
  `before_value` varchar(255) DEFAULT NULL,
  `applied_value` varchar(255) DEFAULT NULL,
  `before_asset_key` varchar(512) DEFAULT NULL,
  `before_asset_content_type` varchar(100) DEFAULT NULL,
  `before_asset_sha256` char(64) DEFAULT NULL,
  `applied_asset_key` varchar(512) DEFAULT NULL,
  `applied_asset_content_type` varchar(100) DEFAULT NULL,
  `applied_asset_sha256` char(64) DEFAULT NULL,
  `apply_status` varchar(20) NOT NULL DEFAULT 'PENDING',
  `restore_status` varchar(20) DEFAULT NULL,
  `error_code` varchar(96) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_theme_snapshot_resource` (`application_id`,`resource_type`,`resource_discord_id`),
  KEY `idx_discord_theme_snapshot_application` (`application_id`,`id`),
  CONSTRAINT `fk_discord_theme_snapshot_application` FOREIGN KEY (`application_id`) REFERENCES `discord_theme_applications` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ck_discord_theme_snapshot_type` CHECK (`resource_type` in ('GUILD_ICON','GUILD_BANNER','CHANNEL','CATEGORY','ROLE')),
  CONSTRAINT `ck_discord_theme_snapshot_apply_status` CHECK (`apply_status` in ('PENDING','APPLIED','SKIPPED','FAILED')),
  CONSTRAINT `ck_discord_theme_snapshot_restore_status` CHECK (`restore_status` is null or `restore_status` in ('RESTORED','DRIFTED','MISSING','SKIPPED','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_operations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `application_id` bigint(20) NOT NULL,
  `guild_id` bigint(20) NOT NULL,
  `operation_key` varchar(96) NOT NULL,
  `operation_type` varchar(12) NOT NULL,
  `actor_discord_user_id` bigint(20) NOT NULL,
  `actor_user_id` int(11) DEFAULT NULL,
  `force_restore` tinyint(1) NOT NULL DEFAULT 0,
  `status` varchar(20) NOT NULL DEFAULT 'PENDING',
  `progress_current` int(11) NOT NULL DEFAULT 0,
  `progress_total` int(11) NOT NULL DEFAULT 0,
  `current_step` varchar(96) DEFAULT NULL,
  `result_json` longtext DEFAULT NULL,
  `error_code` varchar(96) DEFAULT NULL,
  `requested_audited_at` datetime(6) DEFAULT NULL,
  `completion_audited_at` datetime(6) DEFAULT NULL,
  `started_at` datetime(6) DEFAULT NULL,
  `finished_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_theme_operation_key` (`guild_id`,`operation_key`),
  UNIQUE KEY `uq_discord_theme_operation_guild_id` (`guild_id`,`id`),
  UNIQUE KEY `uq_discord_theme_operation_guild_id_app` (`guild_id`,`id`,`application_id`),
  KEY `idx_discord_theme_operation_app` (`application_id`,`operation_type`,`id`),
  KEY `idx_discord_theme_operation_guild_status` (`guild_id`,`status`,`id`),
  KEY `fk_discord_theme_operation_application` (`guild_id`,`application_id`),
  KEY `fk_discord_theme_operation_actor_user` (`actor_user_id`),
  CONSTRAINT `fk_discord_theme_operation_actor_user` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_discord_theme_operation_application` FOREIGN KEY (`guild_id`, `application_id`) REFERENCES `discord_theme_applications` (`guild_id`, `id`) ON DELETE CASCADE,
  CONSTRAINT `ck_discord_theme_operation_type` CHECK (`operation_type` in ('APPLY','RESTORE')),
  CONSTRAINT `ck_discord_theme_operation_status` CHECK (`status` in ('PENDING','RUNNING','SUCCEEDED','PARTIAL','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `partner_external_links` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `partner_id` int(11) NOT NULL,
  `type` varchar(32) NOT NULL,
  `label` varchar(128) DEFAULT NULL,
  `url` varchar(1024) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_partner_external_links_partner` (`partner_id`),
  CONSTRAINT `fk_partner_external_links_partner` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `partner_links` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `partner_id` int(11) NOT NULL,
  `target_type` varchar(32) NOT NULL,
  `target_id` int(11) DEFAULT NULL,
  `external_ref` varchar(255) DEFAULT NULL,
  `label` varchar(128) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_partner_links_partner` (`partner_id`),
  KEY `idx_partner_links_target` (`target_type`,`target_id`),
  CONSTRAINT `fk_partner_links_partner` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `partner_metrics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `partner_id` int(11) NOT NULL,
  `metric_date` date NOT NULL,
  `clicks` bigint(20) NOT NULL DEFAULT 0,
  `invites` bigint(20) NOT NULL DEFAULT 0,
  `conversions` bigint(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_partner_metrics_day` (`partner_id`,`metric_date`),
  CONSTRAINT `fk_partner_metrics_partner` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `partner_token` (
  `partner_id` int(11) NOT NULL,
  `token` varchar(128) NOT NULL,
  `expiration_dtm` datetime NOT NULL,
  PRIMARY KEY (`partner_id`),
  UNIQUE KEY `partner_id` (`partner_id`),
  CONSTRAINT `FK_partner_token_partners` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `stats_monthly_game_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) DEFAULT NULL,
  `month` varchar(50) NOT NULL DEFAULT '',
  `game_name` varchar(128) NOT NULL,
  `seconds` int(11) unsigned NOT NULL,
  `last_update` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique month and game_name` (`month`,`game_name`),
  KEY `FK_stats_monthly_game_activity_discord_servers` (`server_guild_id`),
  CONSTRAINT `FK_stats_monthly_game_activity_discord_servers` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `stats_weekly_game_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL DEFAULT 0,
  `week` varchar(50) NOT NULL DEFAULT '',
  `game_name` varchar(128) NOT NULL,
  `seconds` int(11) unsigned NOT NULL,
  `last_update` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique week and game_name` (`week`,`game_name`),
  KEY `FK_stats_weekly_game_activity_discord_servers` (`server_guild_id`),
  CONSTRAINT `FK_stats_weekly_game_activity_discord_servers` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_ban_discord_effects` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `ban_id` int(11) NOT NULL,
  `identity_user_id` int(11) NOT NULL,
  `discord_user_id` bigint(20) NOT NULL,
  `is_origin` tinyint(1) NOT NULL DEFAULT 0,
  `outcome` varchar(32) NOT NULL,
  `error_code` varchar(64) DEFAULT NULL,
  `attempted_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `reverted_at` datetime(6) DEFAULT NULL,
  `revert_outcome` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_ban_effect_ban_discord` (`ban_id`,`discord_user_id`),
  KEY `idx_user_ban_effect_discord` (`discord_user_id`,`ban_id`),
  KEY `idx_user_ban_effect_identity` (`identity_user_id`,`ban_id`),
  CONSTRAINT `fk_user_ban_effect_ban` FOREIGN KEY (`ban_id`) REFERENCES `user_bans` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_ban_effect_identity_user` FOREIGN KEY (`identity_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `ck_user_ban_effect_is_origin` CHECK (`is_origin` in (0,1)),
  CONSTRAINT `ck_user_ban_effect_outcome` CHECK (`outcome` in ('APPLIED','ALREADY_BANNED','NOT_FOUND','FORBIDDEN','FAILED')),
  CONSTRAINT `ck_user_ban_effect_revert_outcome` CHECK (`revert_outcome` is null or `revert_outcome` in ('REVERTED','ALREADY_UNBANNED','NOT_FOUND','FORBIDDEN','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_custom_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL DEFAULT 0,
  `owner_discord_user_id` bigint(20) NOT NULL,
  `role_id` bigint(20) DEFAULT NULL,
  `color` char(32) DEFAULT '',
  `color2` varchar(32) DEFAULT NULL,
  `icon_id` bigint(32) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `uq_user_custom_roles_guild_owner_discord` (`server_guild_id`,`owner_discord_user_id`),
  KEY `guild_id` (`server_guild_id`) USING BTREE,
  KEY `idx_user_custom_roles_guild_role` (`server_guild_id`,`role_id`),
  CONSTRAINT `FK_user_custom_roles_discord_servers` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_economy` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `bank_balance` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `uq_user_economy_user_server` (`user_id`,`server_guild_id`),
  KEY `user_economy_server_guild_id_discord_servers_guild_id` (`server_guild_id`),
  KEY `idx_user_economy_user_fk_support` (`user_id`),
  CONSTRAINT `user_economy_server_guild_id_discord_servers_guild_id` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`),
  CONSTRAINT `user_economy_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_inventory` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `community_id` int(11) NOT NULL,
  `store_item_id` int(11) NOT NULL DEFAULT 0,
  `owner_user_id` int(11) NOT NULL DEFAULT 0,
  `quantity` int(11) NOT NULL,
  `used_in` datetime DEFAULT NULL,
  `valid_until` datetime DEFAULT NULL,
  `service_metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`service_metadata`)),
  PRIMARY KEY (`id`),
  KEY `FK_user_inventory_communities` (`community_id`),
  KEY `FK_user_inventory_community_store` (`store_item_id`),
  KEY `FK_user_inventory_users` (`owner_user_id`),
  CONSTRAINT `FK_user_inventory_communities` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_user_inventory_community_store` FOREIGN KEY (`store_item_id`) REFERENCES `community_store` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_user_inventory_users` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_level` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `total_xp` bigint(20) NOT NULL DEFAULT 0,
  `current_level` int(11) NOT NULL,
  `daily_recs_count` int(11) DEFAULT NULL,
  `weekly_bump_xp` int(11) DEFAULT NULL,
  `xp_awarded_voice_today` int(11) NOT NULL DEFAULT 0,
  `xp_awarded_voice_day` date DEFAULT NULL,
  `xp_awarded_today` int(11) NOT NULL DEFAULT 0,
  `xp_awarded_day` date DEFAULT NULL,
  `xp_awarded_text_today` int(11) NOT NULL DEFAULT 0,
  `xp_awarded_text_day` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `uk_user_level_user_guild` (`user_id`,`server_guild_id`),
  KEY `user_level_server_guild_id_discord_servers_guild_id` (`server_guild_id`),
  KEY `idx_user_level_user_server` (`user_id`,`server_guild_id`),
  CONSTRAINT `user_level_server_guild_id_discord_servers_guild_id` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`),
  CONSTRAINT `user_level_user_id_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_guild_id` bigint(20) NOT NULL DEFAULT 0,
  `user_id` int(11) NOT NULL,
  `voice_time` int(11) DEFAULT NULL COMMENT 'tempo continuo em call (segundos)',
  `game_time` int(11) DEFAULT NULL COMMENT 'tempo continuo em jogo (segundos)',
  `game_name` varchar(255) DEFAULT NULL COMMENT 'nome do jogo',
  `bumps` int(11) DEFAULT NULL,
  `boops` int(11) DEFAULT NULL,
  `boops_received` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `unique_user_and_guild` (`server_guild_id`,`user_id`),
  KEY `FK_user_records_users` (`user_id`),
  KEY `server_guild_id` (`server_guild_id`),
  CONSTRAINT `FK_user_records_discord_servers` FOREIGN KEY (`server_guild_id`) REFERENCES `community_discord` (`guild_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `FK_user_records_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user_temp_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `disc_community_id` int(11) NOT NULL,
  `disc_user_id` int(11) NOT NULL,
  `role_id` bigint(20) NOT NULL DEFAULT 0,
  `expiring_date` datetime NOT NULL,
  `reason` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `temp_roles_disc_community_id_discord_servers_id` (`disc_community_id`),
  KEY `temp_roles_disc_user_id_discord_user_id` (`disc_user_id`),
  CONSTRAINT `temp_roles_disc_community_id_discord_servers_id` FOREIGN KEY (`disc_community_id`) REFERENCES `community_discord` (`id`),
  CONSTRAINT `temp_roles_disc_user_id_discord_user_id` FOREIGN KEY (`disc_user_id`) REFERENCES `user_discord` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `bump_monthly_reward_grants` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `run_id` bigint(20) NOT NULL,
  `discord_user_id` bigint(20) NOT NULL,
  `rank_position` tinyint(3) unsigned NOT NULL,
  `bump_count` int(10) unsigned NOT NULL,
  `first_bump_at` datetime DEFAULT NULL,
  `coins_amount` int(10) unsigned NOT NULL DEFAULT 0,
  `role_id` bigint(20) DEFAULT NULL,
  `role_days` int(10) unsigned NOT NULL DEFAULT 0,
  `role_expires_at` datetime DEFAULT NULL,
  `coins_applied_at` datetime DEFAULT NULL,
  `role_applied_at` datetime DEFAULT NULL,
  `role_skipped_at` datetime DEFAULT NULL,
  `notification_attempted_at` datetime DEFAULT NULL,
  `notification_sent_at` datetime DEFAULT NULL,
  `last_error` varchar(512) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bump_monthly_reward_grants_run_rank` (`run_id`,`rank_position`),
  UNIQUE KEY `uq_bump_monthly_reward_grants_run_user` (`run_id`,`discord_user_id`),
  KEY `idx_bump_monthly_reward_grants_run` (`run_id`),
  CONSTRAINT `fk_bump_monthly_reward_grants_run` FOREIGN KEY (`run_id`) REFERENCES `bump_monthly_reward_runs` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `ck_bump_monthly_reward_grants_rank_position` CHECK (`rank_position` between 1 and 3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_guild_locks` (
  `guild_id` bigint(20) NOT NULL,
  `lock_token` varchar(96) NOT NULL,
  `operation_type` varchar(12) NOT NULL,
  `operation_id` bigint(20) NOT NULL,
  `application_id` bigint(20) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  PRIMARY KEY (`guild_id`),
  KEY `idx_discord_theme_lock_expiry` (`expires_at`),
  KEY `fk_discord_theme_lock_operation` (`guild_id`,`operation_id`,`application_id`),
  CONSTRAINT `fk_discord_theme_lock_operation` FOREIGN KEY (`guild_id`, `operation_id`, `application_id`) REFERENCES `discord_theme_operations` (`guild_id`, `id`, `application_id`) ON DELETE CASCADE,
  CONSTRAINT `ck_discord_theme_lock_operation` CHECK (`operation_type` in ('APPLY','RESTORE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `discord_theme_operation_steps` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `operation_id` bigint(20) NOT NULL,
  `guild_id` bigint(20) NOT NULL,
  `step_code` varchar(96) NOT NULL,
  `step_status` varchar(20) NOT NULL,
  `message` varchar(512) NOT NULL,
  `progress_current` int(11) NOT NULL DEFAULT 0,
  `progress_total` int(11) NOT NULL DEFAULT 0,
  `detail_json` longtext DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  PRIMARY KEY (`id`),
  KEY `idx_discord_theme_operation_steps` (`operation_id`,`id`),
  KEY `idx_discord_theme_operation_steps_guild` (`guild_id`,`operation_id`,`id`),
  CONSTRAINT `fk_discord_theme_operation_step_operation` FOREIGN KEY (`guild_id`, `operation_id`) REFERENCES `discord_theme_operations` (`guild_id`, `id`) ON DELETE CASCADE,
  CONSTRAINT `ck_discord_theme_operation_step_status` CHECK (`step_status` in ('PENDING','RUNNING','SUCCEEDED','SKIPPED','FAILED','DRIFTED','MISSING'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
