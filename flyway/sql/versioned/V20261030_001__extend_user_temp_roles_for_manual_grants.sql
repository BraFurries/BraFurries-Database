-- Extend the existing, canonical temporary roles ledger in-place.
-- Existing user_temp_roles primary keys, legacy relationships, and rows remain.
-- No shadow table or copy/drop is needed.  NULL canonical keys during rollout
-- preserve compatibility with any pre-deploy Coddy still writing legacy rows.

ALTER TABLE user_temp_roles
  MODIFY COLUMN disc_user_id INT(11) NULL,
  MODIFY COLUMN expiring_date DATETIME(6) NOT NULL,
  MODIFY COLUMN reason VARCHAR(200) NOT NULL,
  ADD COLUMN community_id INT(11) NULL,
  ADD COLUMN guild_id BIGINT(20) NULL,
  ADD COLUMN discord_user_id BIGINT(20) NULL,
  ADD COLUMN grant_source VARCHAR(12) NOT NULL DEFAULT 'LEGACY',
  ADD COLUMN request_id CHAR(36) NULL,
  ADD COLUMN status VARCHAR(12) NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN sync_status VARCHAR(12) NOT NULL DEFAULT 'APPLIED',
  ADD COLUMN role_added_by_bot TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN last_error_code VARCHAR(64) NULL,
  ADD COLUMN created_by_user_id INT(11) NULL,
  ADD COLUMN updated_by_user_id INT(11) NULL,
  ADD COLUMN created_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6),
  ADD COLUMN updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  ADD COLUMN last_checked_at DATETIME(6) NULL,
  ADD COLUMN applied_at DATETIME(6) NULL,
  ADD COLUMN version BIGINT(20) UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN active_discord_user_id BIGINT(20) GENERATED ALWAYS AS (
    CASE WHEN grant_source='MANUAL' AND status='ACTIVE' THEN discord_user_id ELSE NULL END
  ) PERSISTENT;

-- Backfill ALL existing rewards from their real FK relationships.
UPDATE user_temp_roles t
JOIN community_discord cd ON cd.id=t.disc_community_id
JOIN user_discord ud ON ud.id=t.disc_user_id
SET t.community_id=cd.community_id,
    t.guild_id=cd.guild_id,
    t.discord_user_id=ud.discord_user_id,
    -- Preexisting rows lack event timestamps; do not invent a grant or apply date.
    t.created_at=NULL,
    t.updated_at=NULL;

ALTER TABLE user_temp_roles
  ADD UNIQUE KEY uq_utr_manual_request (community_id,request_id),
  ADD UNIQUE KEY uq_utr_manual_active (community_id,guild_id,active_discord_user_id,role_id),
  ADD KEY idx_utr_manual_reconcile (grant_source,sync_status,updated_at,id),
  ADD KEY idx_utr_manual_due (grant_source,status,expiring_date,id),
  ADD KEY idx_utr_target (community_id,guild_id,discord_user_id,role_id,id),
  ADD CONSTRAINT fk_utr_guild FOREIGN KEY (community_id,guild_id)
    REFERENCES community_discord (community_id,guild_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT fk_utr_creator FOREIGN KEY (created_by_user_id)
    REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT fk_utr_updater FOREIGN KEY (updated_by_user_id)
    REFERENCES users (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT ck_utr_source CHECK (grant_source IN ('LEGACY','MANUAL')),
  ADD CONSTRAINT ck_utr_status CHECK (status IN ('ACTIVE','CANCELLED','EXPIRED')),
  ADD CONSTRAINT ck_utr_sync CHECK (sync_status IN ('PENDING','PROCESSING','APPLIED','FAILED')),
  ADD CONSTRAINT ck_utr_owned CHECK (role_added_by_bot IN (0,1)),
  ADD CONSTRAINT ck_utr_manual_shape CHECK (
    grant_source='LEGACY' OR
    (disc_user_id IS NULL AND community_id IS NOT NULL
       AND guild_id IS NOT NULL AND discord_user_id IS NOT NULL
       AND request_id IS NOT NULL AND created_by_user_id IS NOT NULL
       AND updated_by_user_id IS NOT NULL
       AND CHAR_LENGTH(TRIM(reason)) BETWEEN 10 AND 200)
  );
