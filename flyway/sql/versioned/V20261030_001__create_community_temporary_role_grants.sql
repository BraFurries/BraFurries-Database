-- Manual temporary Discord role grants are configured by the API and
-- reconciled by Coddy. Legacy user_temp_roles is untouched.
-- The composite parent key was introduced in V20261029_005.
CREATE TABLE community_temporary_role_grants (
  id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  community_id INT(11) NOT NULL,
  guild_id BIGINT(20) NOT NULL,
  discord_user_id BIGINT(20) NOT NULL,
  role_id BIGINT(20) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  reason VARCHAR(200) NOT NULL,
  request_id CHAR(36) NOT NULL,
  status VARCHAR(12) NOT NULL DEFAULT 'ACTIVE',
  sync_status VARCHAR(12) NOT NULL DEFAULT 'PENDING',
  role_added_by_bot TINYINT(1) NOT NULL DEFAULT 0,
  last_error_code VARCHAR(64) NULL,
  created_by_user_id INT(11) NOT NULL,
  updated_by_user_id INT(11) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  last_checked_at DATETIME(6) NULL,
  applied_at DATETIME(6) NULL,
  version BIGINT(20) UNSIGNED NOT NULL DEFAULT 0,
  active_discord_user_id BIGINT(20) GENERATED ALWAYS AS (
    CASE WHEN status='ACTIVE' THEN discord_user_id ELSE NULL END
  ) PERSISTENT,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ctrg_request (community_id,request_id),
  UNIQUE KEY uq_ctrg_active_target
    (community_id, guild_id, active_discord_user_id, role_id),
  KEY idx_ctrg_reconcile (sync_status, updated_at, id),
  KEY idx_ctrg_due (status, expires_at, id),
  KEY idx_ctrg_target (community_id, guild_id, discord_user_id, role_id, id),
  CONSTRAINT fk_ctrg_guild FOREIGN KEY (community_id,guild_id)
    REFERENCES community_discord (community_id,guild_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ctrg_creator FOREIGN KEY (created_by_user_id)
    REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ctrg_updater FOREIGN KEY (updated_by_user_id)
    REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT ck_ctrg_status CHECK (status IN ('ACTIVE','CANCELLED','EXPIRED')),
  CONSTRAINT ck_ctrg_sync CHECK (sync_status IN ('PENDING','APPLIED','FAILED')),
  CONSTRAINT ck_ctrg_owned CHECK (role_added_by_bot IN (0,1)),
  CONSTRAINT ck_ctrg_reason CHECK (CHAR_LENGTH(TRIM(reason)) BETWEEN 10 AND 200)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
