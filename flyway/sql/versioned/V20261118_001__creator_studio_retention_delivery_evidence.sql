-- Creator Studio: retain independently verified provider-level delivery evidence.
-- Accepted by our SMTP relay is NOT evidence that a recipient mail server
-- accepted the reminder. Even provider confirmation is not proof of inbox/read.
-- Existing notices stay UNCONFIRMED; no data backfill or DELETE is performed.
-- A future authenticated provider adapter must be the only writer of evidence.
ALTER TABLE creator_studio_retention_notices
    -- Exact address captured atomically when claiming the notification; only
    -- locally verified accounts can be claimed. Needed to correlate bounce
    -- after the artist changes their account e-mail. Never expose to Front.
    ADD COLUMN recipient_email VARCHAR(254) NULL,
    ADD COLUMN delivery_state VARCHAR(16) NOT NULL DEFAULT 'UNCONFIRMED',
    ADD COLUMN delivery_provider VARCHAR(32) NULL,
    ADD COLUMN delivery_event_ref VARCHAR(190) NULL,
    ADD COLUMN delivery_evidence_at DATETIME(6) NULL,
    ADD UNIQUE KEY uq_csrn_delivery_event (delivery_provider, delivery_event_ref),
    ADD CONSTRAINT ck_csrn_delivery_state
        CHECK (delivery_state IN ('UNCONFIRMED','SERVER_ACCEPTED','BOUNCED','COMPLAINT')),
    ADD CONSTRAINT ck_csrn_delivery_evidence
        CHECK (
            (delivery_state='SERVER_ACCEPTED'
             AND recipient_email IS NOT NULL
             AND recipient_email<>''
             AND delivery_provider IS NOT NULL
             AND delivery_provider<>''
             AND delivery_event_ref IS NOT NULL
             AND delivery_event_ref<>''
             AND delivery_evidence_at IS NOT NULL)
            OR
            (delivery_state<>'SERVER_ACCEPTED'
             AND delivery_evidence_at IS NULL)
        );
