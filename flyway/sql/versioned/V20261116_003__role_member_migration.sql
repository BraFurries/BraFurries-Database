-- Allow a durable role transfer: source -> destination, member by member.
-- Existing jobs remain valid and keep their historic counters unchanged.
-- Database is the only schema/DDL authority. No Discord effects happen here.
ALTER TABLE guild_role_tool_operations
    ADD COLUMN source_role_id BIGINT(20) NULL AFTER role_id,
    ADD COLUMN removed_count INT UNSIGNED NOT NULL DEFAULT 0 AFTER added_count;

ALTER TABLE guild_role_tool_operations
    DROP CONSTRAINT ck_grto_type;

ALTER TABLE guild_role_tool_operations
    ADD CONSTRAINT ck_grto_type CHECK (
        operation_type IN ('BULK_ADD', 'ROLE_MIGRATE', 'RECOVERY_SCAN', 'RECOVERY_APPLY')
    ),
    ADD CONSTRAINT ck_grto_role_migrate CHECK (
        operation_type <> 'ROLE_MIGRATE'
        OR (
            source_role_id IS NOT NULL
            AND role_id IS NOT NULL
            AND source_role_id <> role_id
            AND preview_fingerprint IS NOT NULL
        )
    );
