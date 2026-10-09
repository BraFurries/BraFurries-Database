-- user_community_status stores the current state of one user inside one Community.
-- Production data was preflighted/reconciled before rollout; this migration only
-- formalizes the already documented cardinality.
ALTER TABLE `user_community_status`
    ADD CONSTRAINT `uk_user_community_status_community_user`
    UNIQUE (`community_id`, `user_id`);
