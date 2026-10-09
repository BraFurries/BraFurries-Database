-- Classify Backup permission-overwrite role targets explicitly.
--
-- Restorable roles are normal guild roles only. @everyone and Discord-managed
-- roles are not recreatable as ordinary roles, but their channel overwrites still
-- need a durable target identity.
--
-- Existing rows are preserved as ROLE targets. Legacy @everyone rows are
-- recognized by their canonical name or by the fact that the default role
-- snowflake equals the source guild snowflake.
ALTER TABLE `backup_overwrites`
    ADD COLUMN `target_type` VARCHAR(24) NOT NULL DEFAULT 'ROLE' AFTER `role_name`,
    ADD COLUMN `target_discord_id` BIGINT NULL AFTER `target_type`;

UPDATE `backup_overwrites` bo
INNER JOIN `backup_roles` br
    ON br.id = bo.role_id
INNER JOIN `backup_channels` bc
    ON bc.id = bo.channel_id
INNER JOIN `backup_discord` bd
    ON bd.id = bc.backup_id
SET
    bo.target_type = CASE
        WHEN br.discord_id = bd.guild_id
          OR (br.name = '@everyone' AND br.position = 0)
            THEN 'EVERYONE'
        ELSE 'ROLE'
    END,
    bo.target_discord_id = br.discord_id;

-- @everyone is not a backup role. Make the FK nullable before detaching
-- special targets; the FK itself remains valid for normal ROLE rows.
ALTER TABLE `backup_overwrites`
    MODIFY COLUMN `role_id` INT NULL DEFAULT NULL;

UPDATE `backup_overwrites`
SET `role_id` = NULL
WHERE `target_type` = 'EVERYONE';

-- Remove only the canonical default-role rows from legacy snapshots. Position 0
-- plus @everyone is used as a safe compatibility fallback for snapshots copied
-- to another guild, where backup_discord.guild_id no longer equals the source
-- default-role snowflake.
DELETE br
FROM `backup_roles` br
INNER JOIN `backup_discord` bd
    ON bd.id = br.backup_id
WHERE br.discord_id = bd.guild_id
   OR (br.name = '@everyone' AND br.position = 0);

ALTER TABLE `backup_overwrites`
    MODIFY COLUMN `target_type` VARCHAR(24) NOT NULL DEFAULT 'ROLE',
    MODIFY COLUMN `target_discord_id` BIGINT NULL DEFAULT NULL,
    ADD INDEX `idx_backup_overwrites_target_discord` (`target_discord_id`),
    ADD CONSTRAINT `ck_backup_overwrites_target_type`
        CHECK (`target_type` IN ('ROLE', 'EVERYONE', 'MANAGED_ROLE')),
    ADD CONSTRAINT `ck_backup_overwrites_target_shape`
        CHECK (
            (
                `target_type` = 'ROLE'
                AND `role_id` IS NOT NULL
            )
            OR
            (
                `target_type` IN ('EVERYONE', 'MANAGED_ROLE')
                AND `role_id` IS NULL
                AND `target_discord_id` IS NOT NULL
            )
        );
