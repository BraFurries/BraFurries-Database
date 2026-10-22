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


def run() -> None:
    down()
    start_empty_database()
    compose(
        "run", "--rm", "--no-deps", "flyway",
        "-locations=filesystem:/flyway/baseline,filesystem:/flyway/official",
        "migrate",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' "
        "AND TABLE_NAME<>'flyway_schema_history'",
        115, "107 legacy + 5 foundation + answers + 2 human-review tables",
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
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='recruitment_processes' "
        "AND COLUMN_NAME='draft_revision' AND DATA_TYPE='bigint' "
        "AND IS_NULLABLE='NO'",
        1, "process-scoped revision column created",
    )
    count(
        "SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS "
        "WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME LIKE 'recruitment_%'",
        16, "all sixteen recruitment foreign keys exist",
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
