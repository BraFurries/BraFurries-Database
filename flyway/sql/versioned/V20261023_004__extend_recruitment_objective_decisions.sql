-- Preserve the exact grade-bearing attempt for objective decisions, or NULL when no
-- valid submission exists. Foreign key includes the same tenant+application+stage.
-- Existing human/manual/vote decisions are unchanged.
ALTER TABLE `recruitment_candidate_attempts`
  ADD UNIQUE KEY `uq_rca_objective_decision_ref`
    (`community_id`,`application_id`,`stage_id`,`id`);

ALTER TABLE `recruitment_stage_decisions`
  DROP CONSTRAINT `ck_rsd_source`,
  ADD COLUMN `objective_attempt_id` BIGINT(20) UNSIGNED NULL,
  ADD KEY `fk_rsd_objective_attempt`
    (`community_id`,`application_id`,`stage_id`,`objective_attempt_id`),
  ADD CONSTRAINT `fk_rsd_objective_attempt` FOREIGN KEY
    (`community_id`,`application_id`,`stage_id`,`objective_attempt_id`)
    REFERENCES `recruitment_candidate_attempts`
      (`community_id`,`application_id`,`stage_id`,`id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT `ck_rsd_source` CHECK
    (`decision_source` IN
      ('MANUAL','VOTE_MAJORITY','VOTE_TIE_REJECT','VOTE_TIE_OVERRIDE','OBJECTIVE_GRADE')),
  ADD CONSTRAINT `ck_rsd_objective_reference` CHECK
    (`decision_source`='OBJECTIVE_GRADE' OR `objective_attempt_id` IS NULL);
