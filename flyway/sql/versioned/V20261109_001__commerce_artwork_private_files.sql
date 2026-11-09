-- Arquivos fonte, versões para impressão e referências de obras comerciais.
-- Objetos vivem no bucket R2 PRIVADO sob commerce/artworks/{artwork_id}/.
-- Nunca usar o bucket público nem persistir links públicos; nenhuma Community
-- pode reivindicar estes dados comerciais exclusivos da BraFurries.
CREATE TABLE `commerce_artwork_files` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `artwork_id` BIGINT UNSIGNED NOT NULL,
    `kind` VARCHAR(16) NOT NULL,
    `original_name` VARCHAR(255) NOT NULL,
    `extension` VARCHAR(12) NOT NULL,
    `media_type` VARCHAR(120) NOT NULL,
    `description` VARCHAR(500) NULL,
    `storage_key` VARCHAR(512) NOT NULL,
    `sha256` CHAR(64) NOT NULL,
    `size_bytes` BIGINT UNSIGNED NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    `uploaded_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `archived_by_user_id` INT(11) NULL,
    `archived_at` DATETIME(6) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_caf_storage_key` (`storage_key`),
    KEY `idx_caf_artwork_status` (`artwork_id`,`status`,`id`),
    KEY `idx_caf_actor` (`uploaded_by_user_id`,`created_at`),
    CONSTRAINT `fk_caf_artwork` FOREIGN KEY (`artwork_id`)
        REFERENCES `commerce_artworks` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_caf_uploader` FOREIGN KEY (`uploaded_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_caf_archiver` FOREIGN KEY (`archived_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_caf_kind` CHECK (`kind` IN
        ('SOURCE','PRINT_READY','EXPORT','REFERENCE')),
    CONSTRAINT `ck_caf_extension` CHECK (`extension` IN
        ('png','jpg','jpeg','webp','pdf','svg','psd','ai','eps','zip')),
    CONSTRAINT `ck_caf_bytes` CHECK (`size_bytes` > 0 AND `size_bytes` <= 26214400),
    CONSTRAINT `ck_caf_sha` CHECK (CHAR_LENGTH(`sha256`) = 64),
    CONSTRAINT `ck_caf_status` CHECK (
        (`status`='ACTIVE' AND `archived_at` IS NULL
          AND `archived_by_user_id` IS NULL)
        OR (`status`='ARCHIVED' AND `archived_at` IS NOT NULL
          AND `archived_by_user_id` IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
