-- WebP thumbnails are separate private objects. Existing selections remain valid.
ALTER TABLE commerce_artwork_files
    DROP CONSTRAINT ck_caf_preview,
    ADD COLUMN preview_storage_key VARCHAR(512) NULL,
    ADD COLUMN preview_sha256 CHAR(64) NULL,
    ADD COLUMN preview_size_bytes BIGINT UNSIGNED NULL,
    ADD COLUMN preview_width SMALLINT UNSIGNED NULL,
    ADD COLUMN preview_height SMALLINT UNSIGNED NULL,
    ADD COLUMN preview_generated_at DATETIME(6) NULL,
    ADD UNIQUE KEY uq_caf_preview_storage_key (preview_storage_key),
    ADD CONSTRAINT ck_caf_preview CHECK (
        (is_preview = 0 OR (is_preview = 1 AND status = 'ACTIVE'
            AND extension IN ('png','jpg','jpeg','webp')
            AND media_type IN ('image/png','image/jpeg','image/webp')))
        AND (
            (preview_storage_key IS NULL AND preview_sha256 IS NULL
                AND preview_size_bytes IS NULL AND preview_width IS NULL
                AND preview_height IS NULL AND preview_generated_at IS NULL
                AND (is_preview = 0 OR size_bytes <= 4194304))
            OR (is_preview = 1 AND preview_storage_key IS NOT NULL
                AND preview_sha256 IS NOT NULL AND CHAR_LENGTH(preview_sha256) = 64
                AND preview_size_bytes IS NOT NULL AND preview_size_bytes BETWEEN 1 AND 1048576
                AND preview_width IS NOT NULL AND preview_width BETWEEN 1 AND 512
                AND preview_height IS NOT NULL AND preview_height BETWEEN 1 AND 512
                AND preview_generated_at IS NOT NULL)
        )
    );
