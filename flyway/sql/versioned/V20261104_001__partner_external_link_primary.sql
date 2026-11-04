-- Partner homepage destination. Keep legacy links and partner records unchanged.
-- Applies after the current schema; deploy API/Front only once this migration is present.
-- All existing links start without a selected primary; public read has a legacy fallback.
ALTER TABLE `partner_external_links`
  ADD COLUMN `is_primary` TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN `primary_partner_id` INT(11)
    AS (CASE WHEN `is_primary` = 1 THEN `partner_id` ELSE NULL END) PERSISTENT,
  ADD CONSTRAINT `ck_partner_external_links_is_primary` CHECK (`is_primary` IN (0, 1)),
  ADD UNIQUE KEY `uq_partner_external_links_one_primary` (`primary_partner_id`);

-- One is_primary=1 link maximum per partner is enforced by the generated unique key.
-- MariaDB permits multiple NULL values (non-primary links).
-- Never run the Flyway production baseline over an existing production database.
