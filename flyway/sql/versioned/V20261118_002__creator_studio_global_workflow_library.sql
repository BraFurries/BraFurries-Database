-- Platform-owned starter templates are NOT tenants and never belong to a Community.
-- Publishing a global template grants no subscription, and never rewrites
-- an artist's private models or already materialized commission steps.
-- Creator Studio private models are still scoped by users.id.
CREATE TABLE creator_studio_global_workflows (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL DEFAULT '',
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_by_user_id INT(11) NULL,
    updated_by_user_id INT(11) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_csgw_name (name),
    KEY idx_csgw_active (active, name, id),
    CONSTRAINT fk_csgw_creator FOREIGN KEY (created_by_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_csgw_editor FOREIGN KEY (updated_by_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csgw_name CHECK (CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT ck_csgw_active CHECK (active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE creator_studio_global_workflow_steps (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    workflow_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,
    position SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_csgws_position (workflow_id, position),
    CONSTRAINT fk_csgws_workflow FOREIGN KEY (workflow_id)
        REFERENCES creator_studio_global_workflows (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_csgws_name CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Exactly one modest starter model is seeded, without user data or permissions.
-- The owner can later rename, deactivate or publish other templates through API.
INSERT INTO creator_studio_global_workflows (name,description)
VALUES ('Processo básico',
        'Um ponto de partida simples para organizar commissions; adapte as etapas ao seu jeito.');

INSERT INTO creator_studio_global_workflow_steps (workflow_id,name,position)
SELECT id,'Alinhamento do pedido',0 FROM creator_studio_global_workflows
 WHERE name='Processo básico';
INSERT INTO creator_studio_global_workflow_steps (workflow_id,name,position)
SELECT id,'Rascunho',1 FROM creator_studio_global_workflows
 WHERE name='Processo básico';
INSERT INTO creator_studio_global_workflow_steps (workflow_id,name,position)
SELECT id,'Revisão',2 FROM creator_studio_global_workflows
 WHERE name='Processo básico';
INSERT INTO creator_studio_global_workflow_steps (workflow_id,name,position)
SELECT id,'Finalização',3 FROM creator_studio_global_workflows
 WHERE name='Processo básico';
INSERT INTO creator_studio_global_workflow_steps (workflow_id,name,position)
SELECT id,'Entrega',4 FROM creator_studio_global_workflows
 WHERE name='Processo básico';
