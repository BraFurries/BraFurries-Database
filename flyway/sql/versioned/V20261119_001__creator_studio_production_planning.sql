-- Optional civil dates, private to the owner and materialized commission.
-- Never propagate a planned date to a reusable stage or workflow template.
ALTER TABLE creator_studio_commissions
    ADD COLUMN planned_on DATE NULL AFTER due_on,
    ADD KEY idx_csc_calendar_planned (owner_user_id, planned_on, id),
    ADD KEY idx_csc_calendar_due (owner_user_id, due_on, id);

ALTER TABLE creator_studio_commission_steps
    ADD COLUMN planned_on DATE NULL AFTER completed_at,
    ADD KEY idx_cscs_calendar_planned (owner_user_id, planned_on, commission_id, id);
