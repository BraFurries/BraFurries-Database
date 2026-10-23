-- First candidate submission storage. Schema authority: BraFurries-Database.
-- Deployed only after the 107-table baseline + recruitment foundation/revision.
-- No existing records are modified; consent columns are nullable for compatibility.

ALTER TABLE `recruitment_applications`
  ADD COLUMN `terms_accepted_at` DATETIME(6) NULL,
  ADD COLUMN `terms_sha256` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  ADD CONSTRAINT `ck_ra_terms_pair` CHECK (
      (`terms_accepted_at` IS NULL AND `terms_sha256` IS NULL)
      OR
      (`terms_accepted_at` IS NOT NULL AND `terms_sha256` IS NOT NULL
       AND `terms_sha256` REGEXP '^[0-9a-f]{64}$')
  );

CREATE TABLE `recruitment_application_answers` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `application_id` BIGINT(20) UNSIGNED NOT NULL,
    `stage_id` BIGINT(20) UNSIGNED NOT NULL,
    `answers_json` LONGTEXT NOT NULL,
    `submitted_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_raa_stage_submission` (`community_id`, `application_id`, `stage_id`),
    CONSTRAINT `fk_raa_application_stage`
      FOREIGN KEY (`community_id`, `application_id`, `stage_id`)
      REFERENCES `recruitment_application_stages` (`community_id`, `application_id`, `stage_id`)
      ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_raa_answers_json` CHECK (JSON_VALID(`answers_json`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
