-- Optional Discord-only announcement, independent from partners.description.
-- Schema authority: BraFurries-Database. Flyway validates on disposable DB;
-- until production baseline adoption, this reviewed DDL is applied manually.
-- Existing partner records and message references remain untouched.
ALTER TABLE partner_discord_publications
    ADD COLUMN announcement_markdown MEDIUMTEXT NULL,
    ADD COLUMN announcement_links_mode VARCHAR(20) NOT NULL DEFAULT 'INLINE_ONLY',
    ADD COLUMN announcement_public_contact VARCHAR(255) NULL,
    ADD COLUMN announcement_part_message_ids VARCHAR(1024) NOT NULL DEFAULT '[]',
    ADD CONSTRAINT ck_pdp_announcement_links_mode
        CHECK (announcement_links_mode IN ('INLINE_ONLY', 'APPEND_MISSING'));

-- announcement_part_message_ids stores ordered Discord continuation message
-- snowflakes as a JSON array of strings. The first announcement message stays
-- in thread_intro_message_id to preserve existing records and references.
-- The application controls the JSON format; no existing Discord resource is
-- modified by this migration.
