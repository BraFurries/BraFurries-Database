-- Remove the legacy uniqueness constraint on Discord guild display names.
-- Discord guild names are not stable identifiers and are not globally unique.
-- The authoritative external identity is community_discord.guild_id.
--
-- This migration intentionally preserves:
--   * PRIMARY KEY (id)
--   * UNIQUE (community_id) -- one Discord network link per Community in V1
--   * UNIQUE (guild_id)     -- one row per Discord guild
--
-- Legacy production evidence names the obsolete unique index exactly `name`.

SET @community_discord_name_unique_exists = (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'community_discord'
      AND INDEX_NAME = 'name'
      AND NON_UNIQUE = 0
      AND COLUMN_NAME = 'name'
);

SET @community_discord_drop_name_unique_sql = IF(
    @community_discord_name_unique_exists > 0,
    'ALTER TABLE `community_discord` DROP INDEX `name`',
    'SELECT 1'
);

PREPARE community_discord_drop_name_unique_stmt
    FROM @community_discord_drop_name_unique_sql;
EXECUTE community_discord_drop_name_unique_stmt;
DEALLOCATE PREPARE community_discord_drop_name_unique_stmt;
