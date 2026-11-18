-- Creator Studio: preserve the exact personal workflow chosen at commission creation.
-- Existing commission steps remain independent snapshots, and historical
-- commissions intentionally stay NULL because their origin cannot be inferred
-- reliably from art type or today's default workflow.
--
-- Scope is the authenticated user/artist, NOT a Discord Community tenant.
-- FK references the artist-owned workflow using the composite owner key.
-- Workflow deletion is already absent from the administrative API; do not
-- cascade changes from workflow definitions to existing commission steps.

ALTER TABLE creator_studio_commissions
    ADD COLUMN source_workflow_id BIGINT UNSIGNED NULL AFTER art_type_id,
    ADD KEY idx_csc_source_workflow (owner_user_id, source_workflow_id),
    ADD CONSTRAINT fk_csc_source_workflow
        FOREIGN KEY (owner_user_id, source_workflow_id)
        REFERENCES creator_studio_workflows (owner_user_id, id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
