-- Opt-in preview of an existing private artwork file; legacy files remain unselected.
ALTER TABLE commerce_artwork_files
    ADD COLUMN is_preview TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN preview_artwork_id BIGINT UNSIGNED
        GENERATED ALWAYS AS (CASE WHEN is_preview = 1 THEN artwork_id ELSE NULL END) PERSISTENT,
    ADD UNIQUE KEY uq_caf_preview_artwork (preview_artwork_id),
    ADD CONSTRAINT ck_caf_preview CHECK (
        is_preview = 0 OR (is_preview = 1 AND status = 'ACTIVE'
            AND extension IN ('png','jpg','jpeg','webp')
            AND media_type IN ('image/png','image/jpeg','image/webp')
            AND size_bytes <= 4194304)
    );
