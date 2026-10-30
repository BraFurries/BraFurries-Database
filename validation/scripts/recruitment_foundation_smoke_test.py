#!/usr/bin/env python3
"""Test recruitment foundation on a fixed disposable MariaDB 10.6 only.

Verifies baseline + new migration, duplicate candidacies, and actual cross-tenant
and cross-version FK rejection. This is not an API authorization test.
"""
from __future__ import annotations

import sys

from smoke_test import (
    DATABASE_NAME, DATABASE_PASSWORD, DATABASE_USER, SmokeFailure,
    assert_no_resources_remain, compose, down, query, require_equal,
    safety_preflight, start_empty_database,
)

MIGRATION_VERSION = "20261021.001"
REVISION_MIGRATION_VERSION = "20261022.001"
APPLICATION_MIGRATION_VERSION = "20261022.002"
HUMAN_REVIEW_MIGRATION_VERSION = "20261022.003"
DECISIONS_MIGRATION_VERSION = "20261022.004"
VOTES_MIGRATION_VERSION = "20261023.001"
ATTEMPTS_MIGRATION_VERSION = "20261023.002"
GRADES_MIGRATION_VERSION = "20261023.003"
OBJECTIVE_DECISIONS_VERSION = "20261023.004"
SCORE_VISIBILITY_VERSION = "20261023.005"
INTEGRITY_EVENTS_VERSION = "20261023.006"
REINSTATEMENTS_VERSION = "20261023.007"
AUTOSAVE_VERSION = "20261023.008"
INCIDENT_NOTICES_VERSION = "20261023.009"


def execute(sql: str, *, check: bool = True):
    return compose(
        "exec", "--no-TTY", "mariadb", "mariadb",
        "--host=127.0.0.1", f"--user={DATABASE_USER}",
        f"--password={DATABASE_PASSWORD}", f"--database={DATABASE_NAME}",
        "--execute=" + sql, check=check,
    )


def count(sql: str, expected: int, description: str) -> None:
    require_equal(query(sql), str(expected), description)


def rejected(sql: str, description: str, *, error_code: int) -> None:
    result = execute(sql, check=False)
    output = (result.stdout + result.stderr).lower()
    if result.returncode == 0 or f"error {error_code} (" not in output:
        raise SmokeFailure(
            f"{description}: expected MariaDB constraint rejection, "
            f"returncode={result.returncode}, output={output[:600]}"
        )
    print(f"PASS: {description}")


def assert_portaria_clarification_uniqueness() -> None:
    """Real MariaDB semantics: only one unfinished ticket, unlimited closed history."""
    execute("INSERT INTO communities (id,name) VALUES (90501,'Ticket Fixture')")
    execute("INSERT INTO community_discord (id,community_id,name,guild_id) "
            "VALUES (90501,90501,'Ticket Guild',90501001)")
    execute("INSERT INTO form_flows (id,name,type,server_guild_id,target_channel_id) "
            "VALUES (90501,'Portaria fixture','portaria',90501001,90501999)")
    execute("INSERT INTO form_submissions (id,flow_id,user_id,guild_id,channel_id) "
            "VALUES (90501,90501,90501777,90501001,90501999),"
            "(90502,90501,90501777,90501001,90501999)")
    execute("INSERT INTO portaria_clarification_tickets "
            "(id,community_id,guild_id,submission_id,applicant_discord_user_id,"
            "requested_by_discord_user_id,reason) "
            "VALUES (90501,90501,90501001,90501,90501777,90501888,"
            "'Esclarecimento inicial de portaria')")
    rejected(
        "INSERT INTO portaria_clarification_tickets "
        "(id,community_id,guild_id,submission_id,applicant_discord_user_id,"
        "requested_by_discord_user_id,reason) "
        "VALUES (90502,90501,90501001,90502,90501777,90501888,"
        "'Segundo ticket indevido ainda aberto')",
        "Unique generated key rejects parallel applicant tickets across submissions",
        error_code=1062,
    )
    execute("UPDATE portaria_clarification_tickets SET status='CLOSED', "
            "discord_channel_id=90501234,opened_at=UTC_TIMESTAMP(6),"
            "closed_at=UTC_TIMESTAMP(6),"
            "closed_by_discord_user_id=90501888,"
            "close_reason='Conversa encerrada com atendimento concluido' "
            "WHERE id=90501")
    execute("INSERT INTO portaria_clarification_tickets "
            "(id,community_id,guild_id,submission_id,applicant_discord_user_id,"
            "requested_by_discord_user_id,reason) "
            "VALUES (90502,90501,90501001,90502,90501777,90501888,"
            "'Segundo atendimento depois do encerramento')")
    count(
        "SELECT COUNT(*) FROM portaria_clarification_tickets "
        "WHERE community_id=90501 AND applicant_discord_user_id=90501777",
        2, "closed history preserved while next ticket can open",
    )



def assert_unified_temp_roles() -> None:
    """Legacy reward survives in-place DDL; manual history shares exactly one table."""
    count(
        "SELECT COUNT(*) FROM user_temp_roles WHERE id=90503 "
        "AND community_id=90503 AND guild_id=90503001 "
        "AND discord_user_id=90503777 AND grant_source='LEGACY' "
        "AND disc_community_id=90503 AND disc_user_id=90503 AND status='ACTIVE'",
        1, "existing legacy grant and identity foreign keys survive migration",
    )
    count(
        "SELECT COUNT(*) FROM user_temp_roles WHERE id=90503 "
        "AND created_at IS NULL AND updated_at IS NULL AND applied_at IS NULL",
        1, "legacy grant must not acquire fictional creation or Discord application dates",
    )
    execute(
        "INSERT INTO user_temp_roles "
        "(disc_community_id,disc_user_id,community_id,guild_id,discord_user_id,"
        "role_id,expiring_date,reason,request_id,grant_source,sync_status,"
        "created_by_user_id,updated_by_user_id) VALUES "
        "(90503,NULL,90503,90503001,90503777,90503444,'2030-01-02',"
        "'Concessao excepcional autorizada','c7628626-2645-4dfa-9fcd-000000000001',"
        "'MANUAL','PENDING',90503,90503)"
    )
    rejected(
        "INSERT INTO user_temp_roles "
        "(disc_community_id,disc_user_id,community_id,guild_id,discord_user_id,"
        "role_id,expiring_date,reason,request_id,grant_source,sync_status,"
        "created_by_user_id,updated_by_user_id) VALUES "
        "(90503,NULL,90503,90503001,90503777,90503444,'2030-01-03',"
        "'Outra concessao indevida','c7628626-2645-4dfa-9fcd-000000000002',"
        "'MANUAL','PENDING',90503,90503)",
        "only one active manual grant for a community/guild/user/role",
        error_code=1062,
    )
    count(
        "SELECT COUNT(*) FROM user_temp_roles WHERE disc_community_id=90503",
        2, "manual grant and legacy reward coexist in the unified ledger",
    )
    execute(
        "UPDATE user_temp_roles SET status='CANCELLED' "
        "WHERE grant_source='MANUAL' AND disc_community_id=90503"
    )
    execute(
        "INSERT INTO user_temp_roles "
        "(disc_community_id,disc_user_id,community_id,guild_id,discord_user_id,"
        "role_id,expiring_date,reason,request_id,grant_source,sync_status,"
        "created_by_user_id,updated_by_user_id) VALUES "
        "(90503,NULL,90503,90503001,90503777,90503444,'2030-01-03',"
        "'Nova concessao excepcional','c7628626-2645-4dfa-9fcd-000000000003',"
        "'MANUAL','PENDING',90503,90503)"
    )
    count(
        "SELECT COUNT(*) FROM user_temp_roles WHERE disc_community_id=90503",
        3, "canceled manual grant remains in history after a new grant opens",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA=DATABASE() "
        "AND TABLE_NAME='community_temporary_role_grants'",
        0, "there is no shadow manual role grant table",
    )


def run() -> None:
    down()
    start_empty_database()
    # Seed one legacy grant before this migration, proving preservation
    # of real foreign keys and backfill of canonical Discord IDs.
    compose(
        "run", "--rm", "--no-deps", "flyway",
        "-locations=filesystem:/flyway/baseline,filesystem:/flyway/official",
        "-target=20261029.005", "migrate",
    )
    execute("INSERT INTO communities (id,name) VALUES (90503,'Legacy Role Fixture')")
    execute("INSERT INTO community_discord (id,community_id,name,guild_id) "
            "VALUES (90503,90503,'Legacy Guild',90503001)")
    execute("INSERT INTO users (id,username) VALUES (90503,'legacy_role_fixture')")
    execute("INSERT INTO user_discord (id,user_id,discord_user_id,username) "
            "VALUES (90503,90503,90503777,'legacy_member')")
    execute("INSERT INTO user_temp_roles "
            "(id,disc_community_id,disc_user_id,role_id,expiring_date,reason) "
            "VALUES (90503,90503,90503,90503444,'2030-01-01','Legacy reward')")
    compose(
        "run", "--rm", "--no-deps", "flyway",
        "-locations=filesystem:/flyway/baseline,filesystem:/flyway/official",
        "migrate",
    )
    assert_unified_temp_roles()
    count(
        "SELECT COUNT(*) FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' "
        "AND TABLE_NAME<>'flyway_schema_history'",
        126, "legacy, recruitment, Portaria clarification, and extended temporary role ledger",
    )
    count(
        "SELECT COUNT(DISTINCT CONSTRAINT_NAME) FROM "
        "information_schema.KEY_COLUMN_USAGE "
        "WHERE TABLE_SCHEMA=DATABASE() "
        "AND TABLE_NAME='portaria_clarification_tickets' "
        "AND CONSTRAINT_NAME IN ('fk_pct_community_guild','fk_pct_submission_guild') "
        "AND REFERENCED_TABLE_NAME IS NOT NULL",
        2, "Portaria tickets have both composite Community/guild/submission foreign keys",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA=DATABASE() "
        "AND TABLE_NAME='portaria_clarification_tickets' "
        "AND INDEX_NAME='uq_pct_one_active_applicant' AND NON_UNIQUE=0",
        3, "unique active-ticket key covers Community, guild and active applicant",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='portaria_clarification_tickets' "
        "AND COLUMN_NAME='active_applicant_discord_user_id' "
        "AND EXTRA LIKE '%GENERATED%'",
        1, "active applicant is a generated nullable unique-key component",
    )
    assert_portaria_clarification_uniqueness()
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() "
        "AND TABLE_NAME='user_temp_roles' "
        "AND COLUMN_NAME='active_discord_user_id' AND EXTRA LIKE '%GENERATED%'",
        1, "active manual grant has a nullable generated key on the existing ledger",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA=DATABASE() "
        "AND TABLE_NAME='user_temp_roles' "
        "AND INDEX_NAME='uq_utr_manual_active' AND NON_UNIQUE=0",
        4, "active manual-grant key includes Community, guild, user and role",
    )
    count(
        "SELECT COUNT(DISTINCT CONSTRAINT_NAME) FROM "
        "information_schema.KEY_COLUMN_USAGE "
        "WHERE TABLE_SCHEMA=DATABASE() "
        "AND TABLE_NAME='user_temp_roles' "
        "AND CONSTRAINT_NAME='fk_utr_guild' AND REFERENCED_TABLE_NAME IS NOT NULL",
        1, "unified ledger has composite Community/guild foreign key",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='portaria_base_config' "
        "AND COLUMN_NAME='clarification_tickets_enabled' "
        "AND COLUMN_DEFAULT='0' AND IS_NULLABLE='NO'",
        1, "Portaria clarification remains disabled by default",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{MIGRATION_VERSION}'",
        1, "recruitment migration recorded exactly once",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{REVISION_MIGRATION_VERSION}'",
        1, "revision migration recorded exactly once",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{APPLICATION_MIGRATION_VERSION}'",
        1, "candidate submission migration recorded exactly once",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{HUMAN_REVIEW_MIGRATION_VERSION}'",
        1, "human-review migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{DECISIONS_MIGRATION_VERSION}'",
        1, "stage-decision migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{VOTES_MIGRATION_VERSION}'",
        1, "collective ballots migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{ATTEMPTS_MIGRATION_VERSION}'",
        1, "candidate attempts migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{GRADES_MIGRATION_VERSION}'",
        1, "objective grading migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{OBJECTIVE_DECISIONS_VERSION}'",
        1, "objective stage finalization migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{SCORE_VISIBILITY_VERSION}'",
        1, "exam score visibility migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{INTEGRITY_EVENTS_VERSION}'",
        1, "exam integrity events migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{REINSTATEMENTS_VERSION}'",
        1, "reinstatement migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{AUTOSAVE_VERSION}'",
        1, "candidate autosave migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='recruitment_candidate_attempts' "
        "AND COLUMN_NAME IN ('draft_answers_json','draft_revision','draft_saved_at')",
        3, "candidate attempt draft fields exist",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success=1 AND version='{INCIDENT_NOTICES_VERSION}'",
        1, "incident notice and receipt schema recorded",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        "WHERE success=1 AND version='20261029.001'",
        1, "focus-warning acknowledgement migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='recruitment_candidate_attempts' "
        "AND COLUMN_NAME='focus_losses_acknowledged'",
        1, "candidate attempt acknowledgement field exists",
    )
    count(
        "SELECT COUNT(*) FROM flyway_schema_history "
        "WHERE success=1 AND version='20261027.002'",
        1, "candidate technical appeal migration recorded",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='recruitment_exam_block_appeals'",
        1, "technical appeal table exists",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='recruitment_processes' "
        "AND COLUMN_NAME='draft_revision' AND DATA_TYPE='bigint' "
        "AND IS_NULLABLE='NO'",
        1, "process-scoped revision column created",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS "
        "WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME LIKE 'recruitment_%'",
        35, "all recruitment foreign keys including candidate appeals exist",
    )

    execute(
        "INSERT INTO users (id,username) VALUES "
        "(981001,'candidate-a'),(981002,'candidate-b'),(981003,'reviewer')"
    )
    execute(
        "INSERT INTO communities (id,name,owner_user_id) VALUES "
        "(981001,'Tenant A',981003),(981002,'Tenant B',981003)"
    )
    execute(
        "INSERT INTO user_community_status "
        "(community_id,user_id,member_since) VALUES "
        "(981001,981001,UTC_TIMESTAMP()),(981002,981002,UTC_TIMESTAMP())"
    )
    execute(
        "INSERT INTO recruitment_processes (id,community_id,title,created_by_user_id) "
        "VALUES (982001,981001,'Process A',981003),"
        "(982002,981002,'Process B',981003)"
    )
    count(
        "SELECT COUNT(*) FROM recruitment_processes "
        "WHERE id IN (982001,982002) AND draft_revision=0",
        2, "old and new draft rows default to zero revision",
    )
    count(
        "SELECT COUNT(*) FROM recruitment_processes "
        "WHERE community_id=981001 AND id=982001 AND status='DRAFT' "
        "AND draft_revision=0",
        1, "revision is tenant-scoped",
    )
    execute(
        "UPDATE recruitment_processes SET draft_revision=draft_revision+1 "
        "WHERE community_id=981001 AND id=982001 "
        "AND status='DRAFT' AND draft_revision=0"
    )
    count(
        "SELECT draft_revision FROM recruitment_processes "
        "WHERE community_id=981001 AND id=982001",
        1, "first writer advances revision atomically",
    )
    execute(
        "UPDATE recruitment_processes SET draft_revision=draft_revision+1 "
        "WHERE community_id=981001 AND id=982001 "
        "AND status='DRAFT' AND draft_revision=0"
    )
    count(
        "SELECT draft_revision FROM recruitment_processes "
        "WHERE community_id=981001 AND id=982001",
        1, "stale writer cannot advance revision",
    )
    count(
        "SELECT draft_revision FROM recruitment_processes "
        "WHERE community_id=981002 AND id=982002",
        0, "second tenant unaffected",
    )
    rejected(
        "INSERT INTO recruitment_process_versions "
        "(id,community_id,process_id,version_number,created_by_user_id) "
        "VALUES (983099,981001,982002,1,981003)",
        "cannot attach tenant B process to tenant A version", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_process_versions "
        "(id,community_id,process_id,version_number,created_by_user_id) "
        "VALUES (983001,981001,982001,1,981003),"
        "(983002,981002,982002,1,981003),"
        "(983003,981001,982001,2,981003)"
    )
    rejected(
        "INSERT INTO recruitment_stages "
        "(id,community_id,process_id,process_version_id,position,"
        "internal_name,public_name,stage_type) "
        "VALUES (984099,981001,982001,983002,1,'Bad','Bad','APPLICATION')",
        "cannot connect stage with mismatched process/version tenant", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_stages "
        "(id,community_id,process_id,process_version_id,position,"
        "internal_name,public_name,stage_type) VALUES "
        "(984001,981001,982001,983001,1,'Review A','In review','ANALYSIS'),"
        "(984002,981002,982002,983002,1,'Review B','In review','ANALYSIS'),"
        "(984003,981001,982001,983003,1,'Review v2','In review','ANALYSIS')"
    )
    rejected(
        "INSERT INTO recruitment_process_versions "
        "(id,community_id,process_id,version_number,created_by_user_id,"
        "eligibility_rules_json) "
        "VALUES (983099,981001,982001,3,981003,'{bad-json')",
        "malformed version rules JSON is rejected", error_code=4025,
    )
    rejected(
        "INSERT INTO recruitment_applications "
        "(id,community_id,process_id,process_version_id,candidate_user_id) "
        "VALUES (985099,981001,982001,983001,981002)",
        "candidate with only tenant B membership cannot apply in tenant A", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_applications "
        "(id,community_id,process_id,process_version_id,candidate_user_id) "
        "VALUES (985099,981001,982001,983002,981001)",
        "candidate cannot reference tenant B process version", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_applications "
        "(id,community_id,process_id,process_version_id,candidate_user_id) "
        "VALUES (985001,981001,982001,983001,981001),"
        "(985002,981002,982002,983002,981002)"
    )
    rejected(
        "INSERT INTO recruitment_applications "
        "(id,community_id,process_id,process_version_id,candidate_user_id) "
        "VALUES (985099,981001,982001,983001,981001)",
        "duplicate candidate application per process is rejected", error_code=1062,
    )
    rejected(
        "INSERT INTO recruitment_application_stages "
        "(community_id,application_id,process_version_id,stage_id) "
        "VALUES (981001,985001,983001,984002)",
        "tenant B stage cannot attach to tenant A application", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_application_stages "
        "(community_id,application_id,process_version_id,stage_id) "
        "VALUES (981001,985001,983003,984003)",
        "same-tenant wrong version stage cannot attach to existing application", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_application_stages "
        "(community_id,application_id,process_version_id,stage_id) VALUES "
        "(981001,985001,983001,984001),"
        "(981002,985002,983002,984002)"
    )
    rejected(
        "INSERT INTO recruitment_application_stages "
        "(community_id,application_id,process_version_id,stage_id) "
        "VALUES (981001,985001,983001,984001)",
        "stage instance cannot be duplicated in an application", error_code=1062,
    )
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='recruitment_applications' "
        "AND COLUMN_NAME IN ('terms_accepted_at','terms_sha256')",
        2, "candidate consent audit columns present",
    )
    execute(
        "UPDATE recruitment_applications "
        "SET terms_accepted_at=UTC_TIMESTAMP(6),terms_sha256=REPEAT('a',64) "
        "WHERE community_id=981001 AND id=985001"
    )
    rejected(
        "INSERT INTO recruitment_application_answers "
        "(community_id,application_id,stage_id,answers_json) "
        "VALUES (981001,985001,984002,'{}')",
        "answer cannot link to another tenant's stage", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_application_answers "
        "(community_id,application_id,stage_id,answers_json) "
        "VALUES (981002,985001,984001,'{}')",
        "answer cannot link to another tenant's application", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_application_answers "
        "(community_id,application_id,stage_id,answers_json) "
        "VALUES (981001,985001,984001,'{invalid-json')",
        "malformed answers JSON is rejected", error_code=4025,
    )
    execute(
        "INSERT INTO recruitment_application_answers "
        "(community_id,application_id,stage_id,answers_json) "
        "VALUES (981001,985001,984001,'{}'),(981002,985002,984002,'{}')"
    )
    rejected(
        "INSERT INTO recruitment_application_answers "
        "(community_id,application_id,stage_id,answers_json) "
        "VALUES (981001,985001,984001,'{}')",
        "duplicate answers for the same application stage rejected", error_code=1062,
    )
    count(
        "SELECT COUNT(*) FROM recruitment_application_stages s "
        "JOIN recruitment_applications a ON a.community_id=s.community_id "
        "AND a.id=s.application_id "
        "WHERE s.community_id=981001 AND a.community_id=981001",
        1, "scoped application query sees only tenant A",
    )
    execute(
        "INSERT INTO recruitment_stage_reviewers "
        "(community_id,process_version_id,stage_id,user_id,created_by_user_id) "
        "VALUES (981001,983001,984001,981001,981003)"
    )
    rejected(
        "INSERT INTO recruitment_stage_reviewers "
        "(community_id,process_version_id,stage_id,user_id,created_by_user_id) "
        "VALUES (981001,983001,984001,981002,981003)",
        "reviewer from other Community denied by composite FK", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_stage_reviewers "
        "(community_id,process_version_id,stage_id,user_id,role_id,created_by_user_id) "
        "VALUES (981001,983001,984001,981001,123,981003)",
        "assignment cannot contain both a person and a role", error_code=4025,
    )
    execute(
        "INSERT INTO recruitment_stage_assessments "
        "(community_id,application_id,stage_id,evaluator_user_id,score,opinion,staff_answers_json) "
        "VALUES (981001,985001,984001,981001,85.5,'Reviewed','{}')"
    )
    rejected(
        "INSERT INTO recruitment_stage_assessments "
        "(community_id,application_id,stage_id,evaluator_user_id,score) "
        "VALUES (981001,985001,984001,981001,10)",
        "duplicate assessment for same evaluator/stage denied", error_code=1062,
    )
    rejected(
        "INSERT INTO recruitment_stage_assessments "
        "(community_id,application_id,stage_id,evaluator_user_id,score) "
        "VALUES (981001,985001,984002,981001,10)",
        "assessment cannot refer to other Community stage", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_stage_assessments "
        "(community_id,application_id,stage_id,evaluator_user_id,score) "
        "VALUES (981001,985001,984001,981001,120)",
        "out-of-range assessment score denied", error_code=4025,
    )
    rejected(
        "INSERT INTO recruitment_stage_votes "
        "(community_id,application_id,stage_id,voter_user_id,choice) "
        "VALUES (981002,985001,984001,981001,'APPROVE')",
        "ballot cannot cross Community boundaries", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_stage_votes "
        "(community_id,application_id,stage_id,voter_user_id,choice) "
        "VALUES (981001,985001,984001,981003,'APPROVE')",
        "ballot requires an assessment by the same voter", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_stage_votes "
        "(community_id,application_id,stage_id,voter_user_id,choice) "
        "VALUES (981001,985001,984001,981001,'APPROVE')"
    )
    rejected(
        "INSERT INTO recruitment_stage_votes "
        "(community_id,application_id,stage_id,voter_user_id,choice) "
        "VALUES (981001,985001,984001,981001,'REJECT')",
        "voter cannot vote twice", error_code=1062,
    )
    rejected(
        "UPDATE recruitment_stage_votes SET choice='ABSTAIN' "
        "WHERE community_id=981001 AND application_id=985001 AND stage_id=984001",
        "unsupported ballot choice is rejected", error_code=4025,
    )
    count(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='recruitment_stage_decisions' "
        "AND COLUMN_NAME='decision_source' AND COLUMN_DEFAULT LIKE '%MANUAL%'",
        1, "existing manual decisions retain the default source",
    )
    execute(
        "INSERT INTO recruitment_stage_decisions "
        "(community_id,application_id,stage_id,decided_by_user_id,outcome,reason) "
        "VALUES (981001,985001,984001,981001,'APPROVE','Manual decision')"
    )
    rejected(
        "INSERT INTO recruitment_stage_decisions "
        "(community_id,application_id,stage_id,decided_by_user_id,outcome) "
        "VALUES (981001,985001,984001,981001,'APPROVE')",
        "a stage can be decided only once", error_code=1062,
    )
    rejected(
        "INSERT INTO recruitment_stage_decisions "
        "(community_id,application_id,stage_id,decided_by_user_id,outcome) "
        "VALUES (981001,985001,984002,981001,'APPROVE')",
        "decision cannot refer to another Community stage", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_stage_decisions "
        "(community_id,application_id,stage_id,decided_by_user_id,outcome) "
        "VALUES (981002,985002,984002,981001,'APPROVE')",
        "decision actor must belong to the same Community", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_stage_decisions "
        "(community_id,application_id,stage_id,decided_by_user_id,outcome) "
        "VALUES (981002,985002,984002,981002,'REJECT')",
        "rejected stage must have a reason", error_code=4025,
    )
    execute(
        "INSERT INTO recruitment_stage_attempt_policies "
        "(community_id,process_version_id,stage_id,max_attempts,"
        "time_limit_seconds,hard_deadline) "
        "VALUES (981001,983001,984001,2,1800,1)"
    )
    rejected(
        "INSERT INTO recruitment_stage_attempt_policies "
        "(community_id,process_version_id,stage_id,max_attempts,time_limit_seconds) "
        "VALUES (981001,983002,984002,2,1800)",
        "tenant A cannot configure tenant B stage policy", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_candidate_attempts "
        "(community_id,application_id,process_version_id,stage_id,"
        "attempt_number,expires_at) VALUES "
        "(981002,985001,983001,984001,1,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 30 MINUTE))",
        "attempt cannot cross Community", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_candidate_attempts "
        "(community_id,application_id,process_version_id,stage_id,"
        "attempt_number,expires_at) VALUES "
        "(981001,985001,983001,984001,1,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 30 MINUTE))"
    )
    rejected(
        "INSERT INTO recruitment_candidate_attempts "
        "(community_id,application_id,process_version_id,stage_id,"
        "attempt_number,expires_at) VALUES "
        "(981001,985001,983001,984001,1,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 30 MINUTE))",
        "reusing attempt number is forbidden", error_code=1062,
    )
    rejected(
        "UPDATE recruitment_candidate_attempts SET focus_losses_acknowledged=1 "
        "WHERE community_id=981001 AND application_id=985001",
        "candidate cannot acknowledge an unrecorded loss", error_code=4025,
    )
    execute(
        "UPDATE recruitment_candidate_attempts "
        "SET focus_losses=1,focus_losses_acknowledged=1 "
        "WHERE community_id=981001 AND application_id=985001"
    )
    count(
        "SELECT COUNT(*) FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 "
        "AND focus_losses=1 AND focus_losses_acknowledged=1",
        1, "recorded warning can be acknowledged",
    )
    execute(
        "UPDATE recruitment_candidate_attempts "
        "SET focus_losses=0,focus_losses_acknowledged=0 "
        "WHERE community_id=981001 AND application_id=985001"
    )
    rejected(
        "INSERT INTO recruitment_exam_block_appeals "
        "(community_id,attempt_id,application_id,stage_id,candidate_user_id,reason) "
        "SELECT 981002,id,application_id,stage_id,981002,"
        "'System notification interrupted the assessment window' "
        "FROM recruitment_candidate_attempts WHERE community_id=981001 "
        "AND application_id=985001 AND attempt_number=1",
        "technical appeal cannot cross Community even for valid foreign member",
        error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_exam_block_appeals "
        "(community_id,attempt_id,application_id,stage_id,candidate_user_id,reason) "
        "SELECT community_id,id,application_id,stage_id,981001,"
        "'System notification interrupted the assessment window' "
        "FROM recruitment_candidate_attempts WHERE community_id=981001 "
        "AND application_id=985001 AND attempt_number=1"
    )
    rejected(
        "INSERT INTO recruitment_exam_block_appeals "
        "(community_id,attempt_id,application_id,stage_id,candidate_user_id,reason) "
        "SELECT community_id,id,application_id,stage_id,981001,"
        "'System notification interrupted the assessment window' "
        "FROM recruitment_candidate_attempts WHERE community_id=981001 "
        "AND application_id=985001 AND attempt_number=1",
        "technical appeal can be requested only once per attempt", error_code=1062,
    )
    rejected(
        "UPDATE recruitment_exam_block_appeals SET status='DENIED' "
        "WHERE community_id=981001 AND application_id=985001",
        "review denial must contain reviewer, reason and review timestamp",
        error_code=4025,
    )
    count(
        "SELECT COUNT(*) FROM recruitment_exam_block_appeals "
        "WHERE community_id=981001 AND application_id=985001 AND status='PENDING'",
        1, "pending technical appeal remains intact after invalid status changes",
    )
    rejected(
        "INSERT INTO recruitment_candidate_attempts "
        "(community_id,application_id,process_version_id,stage_id,"
        "attempt_number,expires_at,status) VALUES "
        "(981001,985001,983001,984001,2,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 30 MINUTE),'SUBMITTED')",
        "submitted attempts must have submitted timestamp and JSON", error_code=4025,
    )
    count(
        "SELECT COUNT(*) FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 "
        "AND draft_revision=0 AND draft_answers_json IS NULL AND draft_saved_at IS NULL",
        1, "new attempts have an empty draft revision",
    )
    rejected(
        "UPDATE recruitment_candidate_attempts SET draft_answers_json='{broken' "
        "WHERE community_id=981001 AND application_id=985001 AND attempt_number=1",
        "malformed autosaved draft JSON rejected", error_code=4025,
    )
    rejected(
        "UPDATE recruitment_candidate_attempts SET answers_json='{broken' "
        "WHERE community_id=981001 AND application_id=985001 AND attempt_number=1",
        "invalid answer JSON rejected", error_code=4025,
    )
    count(
        "SELECT COUNT(*) FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 AND status='STARTED'",
        1, "candidate attempt is scoped",
    )
    rejected(
        "UPDATE recruitment_stage_attempt_policies "
        "SET passing_percentage=70.00 "
        "WHERE community_id=981001 AND stage_id=984001",
        "incomplete score policy cannot leave a bare cutoff", error_code=4025,
    )
    execute(
        "UPDATE recruitment_stage_attempt_policies "
        "SET passing_percentage=70.00,result_strategy='BEST' "
        "WHERE community_id=981001 AND stage_id=984001"
    )
    rejected(
        "UPDATE recruitment_stage_attempt_policies SET result_strategy='FIRST' "
        "WHERE community_id=981001 AND stage_id=984001",
        "unrecognized attempt strategy is rejected", error_code=4025,
    )
    rejected(
        "INSERT INTO recruitment_candidate_attempt_grades "
        "(community_id,attempt_id,earned_points,possible_points,"
        "correct_questions,total_questions,passing_percentage,passed) "
        "VALUES (981002,1,5,10,1,2,70.00,0)",
        "grade cannot cross Community", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_candidate_attempt_grades "
        "(community_id,attempt_id,earned_points,possible_points,"
        "correct_questions,total_questions,passing_percentage,passed) "
        "SELECT community_id,id,8,10,1,2,70.00,1 "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 AND attempt_number=1"
    )
    rejected(
        "INSERT INTO recruitment_candidate_attempt_grades "
        "(community_id,attempt_id,earned_points,possible_points,"
        "correct_questions,total_questions,passing_percentage,passed) "
        "SELECT community_id,id,8,10,1,2,70.00,1 "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 AND attempt_number=1",
        "attempt can be graded only once", error_code=1062,
    )
    rejected(
        "UPDATE recruitment_candidate_attempt_grades "
        "SET earned_points=11 WHERE community_id=981001",
        "earned score cannot exceed possible points", error_code=4025,
    )
    rejected(
        "UPDATE recruitment_stage_decisions "
        "SET decision_source='OBJECTIVE_GRADE', objective_attempt_id=987654321 "
        "WHERE community_id=981001 AND application_id=985001 AND stage_id=984001",
        "manual decision cannot attach a missing objective attempt", error_code=1452,
    )
    rejected(
        "UPDATE recruitment_stage_decisions "
        "SET decision_source='MANUAL', objective_attempt_id=(SELECT id FROM "
        "recruitment_candidate_attempts WHERE community_id=981001 "
        "AND application_id=985001 AND stage_id=984001 LIMIT 1) "
        "WHERE community_id=981001 AND application_id=985001 AND stage_id=984001",
        "manual decision cannot reference an objective attempt", error_code=4025,
    )
    execute(
        "UPDATE recruitment_stage_decisions "
        "SET decision_source='OBJECTIVE_GRADE', objective_attempt_id=(SELECT id FROM "
        "recruitment_candidate_attempts WHERE community_id=981001 "
        "AND application_id=985001 AND stage_id=984001 LIMIT 1) "
        "WHERE community_id=981001 AND application_id=985001 AND stage_id=984001"
    )
    count(
        "SELECT COUNT(*) FROM recruitment_stage_decisions "
        "WHERE community_id=981001 AND application_id=985001 "
        "AND decision_source='OBJECTIVE_GRADE' AND objective_attempt_id IS NOT NULL",
        1, "objective decision references real attempt from same Community and stage",
    )
    count(
        "SELECT COUNT(*) FROM recruitment_stage_attempt_policies "
        "WHERE score_visibility='PRIVATE'",
        1, "private-by-default score policy",
    )
    execute(
        "UPDATE recruitment_stage_attempt_policies SET "
        "score_visibility='AFTER_SUBMISSION' "
        "WHERE community_id=981001 AND stage_id=984001"
    )
    rejected(
        "UPDATE recruitment_stage_attempt_policies SET "
        "score_visibility='PUBLIC_RESULT' "
        "WHERE community_id=981001 AND stage_id=984001",
        "final result cannot be exposed through exam-grade visibility",
        error_code=4025,
    )
    rejected(
        "INSERT INTO recruitment_exam_integrity_events "
        "(community_id,attempt_id,event_uuid,event_type,source) "
        "SELECT 981002,id,'00000000-0000-4000-8000-000000000001',"
        "'FOCUS_LOST','TAB_HIDDEN' FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1",
        "cross-Community exam events forbidden", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_exam_integrity_events "
        "(community_id,attempt_id,event_uuid,event_type,source) "
        "SELECT community_id,id,'00000000-0000-4000-8000-000000000002',"
        "'FOCUS_LOST','TAB_HIDDEN' FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1"
    )
    rejected(
        "INSERT INTO recruitment_exam_integrity_events "
        "(community_id,attempt_id,event_uuid,event_type,source) "
        "SELECT community_id,id,'00000000-0000-4000-8000-000000000002',"
        "'FOCUS_LOST','TAB_HIDDEN' FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1",
        "retries with same event UUID are idempotently unique", error_code=1062,
    )
    rejected(
        "INSERT INTO recruitment_exam_integrity_events "
        "(community_id,attempt_id,event_uuid,event_type,source) "
        "SELECT community_id,id,'00000000-0000-4000-8000-000000000003',"
        "'FOCUS_LOST','COPY' FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1",
        "focus event source must match its type", error_code=4025,
    )
    execute(
        "INSERT INTO user_community_status (community_id,user_id,member_since) "
        "VALUES (981001,981003,UTC_TIMESTAMP())"
    )
    rejected(
        "INSERT INTO recruitment_exam_reinstatements "
        "(community_id,attempt_id,application_id,stage_id,reviewed_by_user_id,"
        "reason,previous_focus_losses,original_started_at,original_expires_at,expires_at) "
        "SELECT 981002,id,application_id,stage_id,981002,"
        "'Erro de perda de foco reconhecido e documentado',3,started_at,expires_at,"
        "DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 60 MINUTE) "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1",
        "reinstatement cannot cross Community FK", error_code=1452,
    )
    rejected(
        "INSERT INTO recruitment_exam_reinstatements "
        "(community_id,attempt_id,application_id,stage_id,reviewed_by_user_id,"
        "reason,previous_focus_losses,original_started_at,original_expires_at,expires_at) "
        "SELECT community_id,id,application_id,stage_id,981003,"
        "'curto',3,started_at,expires_at,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 60 MINUTE) "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1",
        "reinstatement reason minimum length enforced", error_code=4025,
    )
    # The audit default must be UTC even on a non-UTC SQL session.
    execute(
        "SET time_zone='+03:00'; "
        "INSERT INTO recruitment_exam_reinstatements "
        "(community_id,attempt_id,application_id,stage_id,reviewed_by_user_id,"
        "reason,previous_focus_losses,original_started_at,original_expires_at,expires_at) "
        "SELECT community_id,id,application_id,stage_id,981003,"
        "'Perda de foco causada por um alerta do sistema',3,started_at,expires_at,"
        "DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 60 MINUTE) "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1"
    )
    count(
        "SELECT COUNT(*) FROM recruitment_exam_reinstatements "
        "WHERE community_id=981001 "
        "AND ABS(TIMESTAMPDIFF(SECOND,reinstated_at,UTC_TIMESTAMP(6)))<5",
        1, "reinstatement audit remains UTC in non-UTC SQL sessions",
    )
    count(
        "SELECT COUNT(*) FROM recruitment_exam_reinstatements r "
        "JOIN recruitment_candidate_attempts a ON a.community_id=r.community_id "
        "AND a.id=r.attempt_id "
        "WHERE r.community_id=981001 "
        "AND r.original_started_at=a.started_at "
        "AND r.original_expires_at=a.expires_at",
        1, "original attempt timing is captured for later audit",
    )
    rejected(
        "INSERT INTO recruitment_exam_reinstatements "
        "(community_id,attempt_id,application_id,stage_id,reviewed_by_user_id,"
        "reason,previous_focus_losses,original_started_at,original_expires_at,expires_at) "
        "SELECT community_id,id,application_id,stage_id,981003,"
        "'Duplicação não autorizada da liberação administrativa',3,started_at,expires_at,"
        "DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 60 MINUTE) "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1",
        "only one restoration per attempt", error_code=1062,
    )
    execute(
        "INSERT INTO recruitment_exam_incident_notices "
        "(community_id,application_id,stage_id,attempt_id,event_type) "
        "SELECT community_id,application_id,stage_id,id,'BLOCKED' "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1"
    )
    rejected(
        "INSERT INTO recruitment_exam_incident_notices "
        "(community_id,application_id,stage_id,attempt_id,event_type) "
        "SELECT 981002,application_id,stage_id,id,'BLOCKED' "
        "FROM recruitment_candidate_attempts "
        "WHERE community_id=981001 AND application_id=985001 LIMIT 1",
        "cross-Community notice forbidden", error_code=1452,
    )
    execute(
        "INSERT INTO recruitment_exam_notice_reads (community_id,notice_id,user_id) "
        "SELECT community_id,id,981001 FROM recruitment_exam_incident_notices "
        "WHERE community_id=981001 LIMIT 1"
    )
    rejected(
        "INSERT INTO recruitment_exam_notice_reads (community_id,notice_id,user_id) "
        "SELECT 981002,id,981003 FROM recruitment_exam_incident_notices "
        "WHERE community_id=981001 LIMIT 1",
        "cross-Community acknowledgement forbidden", error_code=1452,
    )
    compose(
        "run", "--rm", "--no-deps", "flyway",
        "-locations=filesystem:/flyway/baseline,filesystem:/flyway/official",
        "validate",
    )
    print("PASS: recruitment foundation migration + tenant/version isolation")


def main() -> int:
    result = 0
    preflight_accepted = False
    try:
        safety_preflight()
        preflight_accepted = True
        run()
    except SmokeFailure as error:
        print(f"Recruitment smoke failed: {error}", file=sys.stderr)
        result = 1
    finally:
        if preflight_accepted:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Cleanup failed: {error}", file=sys.stderr)
                result = 1
    return result


if __name__ == "__main__":
    raise SystemExit(main())
