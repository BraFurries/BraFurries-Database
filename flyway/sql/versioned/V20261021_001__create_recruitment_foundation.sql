-- Recruitment process core (BraFurries Community only at the API authorization layer).
-- Additive schema; no existing table, existing row, or production Flyway history is touched.
-- The API must enforce tenant eligibility, permissions and publication transitions.
-- Every cross-record FK repeats community_id; process/version FKs also preserve identity.

CREATE TABLE `recruitment_processes` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `title` VARCHAR(160) NOT NULL,
    `description` TEXT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    `visibility` VARCHAR(20) NOT NULL DEFAULT 'PRIVATE',
    `enrollment_status` VARCHAR(20) NOT NULL DEFAULT 'CLOSED',
    `enrollment_starts_at` DATETIME(6) NULL,
    `enrollment_ends_at` DATETIME(6) NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rp_community_id` (`community_id`, `id`),
    KEY `idx_rp_discovery` (`community_id`, `visibility`, `status`),
    KEY `fk_rp_creator` (`created_by_user_id`),
    CONSTRAINT `fk_rp_community` FOREIGN KEY (`community_id`)
        REFERENCES `communities` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_rp_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_rp_status` CHECK (`status` IN
        ('DRAFT','SCHEDULED','ACTIVE','PAUSED','FINISHED','CANCELLED','ARCHIVED')),
    CONSTRAINT `ck_rp_visibility` CHECK (`visibility` IN ('PUBLIC','UNLISTED','PRIVATE')),
    CONSTRAINT `ck_rp_enrollment` CHECK (`enrollment_status` IN ('SCHEDULED','OPEN','CLOSED')),
    CONSTRAINT `ck_rp_enrollment_window` CHECK (
        `enrollment_starts_at` IS NULL OR `enrollment_ends_at` IS NULL OR
        `enrollment_starts_at` < `enrollment_ends_at`
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `recruitment_process_versions` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `process_id` BIGINT(20) UNSIGNED NOT NULL,
    `version_number` INT(10) UNSIGNED NOT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    `eligibility_rules_json` LONGTEXT NULL,
    `terms_json` LONGTEXT NULL,
    `created_by_user_id` INT(11) NOT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `published_at` DATETIME(6) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rpv_scoped_identity` (`community_id`, `process_id`, `id`),
    UNIQUE KEY `uq_rpv_version` (`community_id`, `process_id`, `version_number`),
    KEY `fk_rpv_creator` (`created_by_user_id`),
    CONSTRAINT `fk_rpv_process` FOREIGN KEY (`community_id`, `process_id`)
        REFERENCES `recruitment_processes` (`community_id`, `id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_rpv_creator` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `users` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_rpv_version` CHECK (`version_number` > 0),
    CONSTRAINT `ck_rpv_status` CHECK (`status` IN ('DRAFT','PUBLISHED','SUPERSEDED')),
    CONSTRAINT `ck_rpv_eligibility_json` CHECK (
        `eligibility_rules_json` IS NULL OR JSON_VALID(`eligibility_rules_json`)
    ),
    CONSTRAINT `ck_rpv_terms_json` CHECK (
        `terms_json` IS NULL OR JSON_VALID(`terms_json`)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `recruitment_stages` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `process_id` BIGINT(20) UNSIGNED NOT NULL,
    `process_version_id` BIGINT(20) UNSIGNED NOT NULL,
    `position` INT(10) UNSIGNED NOT NULL,
    `internal_name` VARCHAR(160) NOT NULL,
    `public_name` VARCHAR(160) NOT NULL,
    `stage_type` VARCHAR(24) NOT NULL,
    `candidate_form_json` LONGTEXT NULL,
    `staff_form_json` LONGTEXT NULL,
    `evaluation_config_json` LONGTEXT NULL,
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rs_version_position` (`community_id`, `process_version_id`, `position`),
    UNIQUE KEY `uq_rs_scoped_identity` (`community_id`, `process_version_id`, `id`),
    KEY `fk_rs_version` (`community_id`, `process_id`, `process_version_id`),
    CONSTRAINT `fk_rs_version` FOREIGN KEY (`community_id`, `process_id`, `process_version_id`)
        REFERENCES `recruitment_process_versions` (`community_id`, `process_id`, `id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_rs_stage_type` CHECK (`stage_type` IN
        ('APPLICATION','ANALYSIS','HUMAN_EVALUATION','AUTO_EVALUATION',
         'INTERVIEW','DECISION','CUSTOM')),
    CONSTRAINT `ck_rs_candidate_form` CHECK (
        `candidate_form_json` IS NULL OR JSON_VALID(`candidate_form_json`)
    ),
    CONSTRAINT `ck_rs_staff_form` CHECK (
        `staff_form_json` IS NULL OR JSON_VALID(`staff_form_json`)
    ),
    CONSTRAINT `ck_rs_config` CHECK (
        `evaluation_config_json` IS NULL OR JSON_VALID(`evaluation_config_json`)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `recruitment_applications` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `process_id` BIGINT(20) UNSIGNED NOT NULL,
    `process_version_id` BIGINT(20) UNSIGNED NOT NULL,
    `candidate_user_id` INT(11) NOT NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'IN_PROGRESS',
    `submitted_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `resolved_at` DATETIME(6) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ra_process_candidate` (`community_id`, `process_id`, `candidate_user_id`),
    UNIQUE KEY `uq_ra_scoped_identity` (`community_id`, `id`, `process_version_id`),
    KEY `idx_ra_candidate` (`community_id`, `candidate_user_id`, `submitted_at`),
    KEY `fk_ra_version` (`community_id`, `process_id`, `process_version_id`),
    CONSTRAINT `fk_ra_version` FOREIGN KEY (`community_id`, `process_id`, `process_version_id`)
        REFERENCES `recruitment_process_versions` (`community_id`, `process_id`, `id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_ra_membership` FOREIGN KEY (`community_id`, `candidate_user_id`)
        REFERENCES `user_community_status` (`community_id`, `user_id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_ra_status` CHECK (`status` IN
        ('IN_PROGRESS','ON_HOLD','AWAITING_PUBLICATION','APPROVED',
         'REJECTED','WITHDRAWN','CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `recruitment_application_stages` (
    `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `community_id` INT(11) NOT NULL,
    `application_id` BIGINT(20) UNSIGNED NOT NULL,
    `process_version_id` BIGINT(20) UNSIGNED NOT NULL,
    `stage_id` BIGINT(20) UNSIGNED NOT NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'PENDING',
    `publicly_available_at` DATETIME(6) NULL,
    `entered_at` DATETIME(6) NULL,
    `completed_at` DATETIME(6) NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ras_application_stage` (`community_id`, `application_id`, `stage_id`),
    UNIQUE KEY `uq_ras_scoped_identity` (`community_id`, `id`),
    KEY `fk_ras_application` (`community_id`, `application_id`, `process_version_id`),
    KEY `fk_ras_stage` (`community_id`, `process_version_id`, `stage_id`),
    CONSTRAINT `fk_ras_application` FOREIGN KEY
        (`community_id`, `application_id`, `process_version_id`)
        REFERENCES `recruitment_applications` (`community_id`, `id`, `process_version_id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `fk_ras_stage` FOREIGN KEY
        (`community_id`, `process_version_id`, `stage_id`)
        REFERENCES `recruitment_stages` (`community_id`, `process_version_id`, `id`)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT `ck_ras_status` CHECK (`status` IN
        ('PENDING','IN_PROGRESS','AWAITING_CANDIDATE','AWAITING_REVIEW',
         'AWAITING_PUBLICATION','COMPLETED','SKIPPED','BLOCKED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
