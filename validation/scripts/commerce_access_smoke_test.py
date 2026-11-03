#!/usr/bin/env python3
"""Validate the commercial ACL foundation using disposable MariaDB only.

No customer, production or shared datasource is used.
"""
from __future__ import annotations

import sys

from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight,
    start_empty_database,
)

def verify_access_tables() -> None:
    for table in (
        "commerce_authorized_users", "commerce_user_permissions",
        "commerce_role_permissions", "commerce_access_audit",
    ):
        require_equal(
            query(
                "SELECT COUNT(*) FROM information_schema.TABLES "
                f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}'"
            ), "1", f"{table} migrated"
        )
        require_equal(query(f"SELECT COUNT(*) FROM {table}"), "0", f"{table} starts empty")

    query(
        "INSERT INTO users (id, display_name) VALUES "
        "(9011, 'Commerce owner'), (9012, 'Approved artist'), (9013, 'Other')"
    )
    query(
        "INSERT INTO communities (id, name) VALUES "
        "(9011, 'BraFurries synthetic'), (9012, 'External synthetic')"
    )
    query(
        "INSERT INTO community_team_roles (id, community_id, name, active) VALUES "
        "(9011, 9011, 'Commercial staff', 1), "
        "(9012, 9012, 'Other Community role', 1)"
    )
    query(
        "INSERT INTO commerce_authorized_users "
        "(user_id, approved_by_user_id) VALUES (9012, 9011)"
    )
    expect_sql_failure(
        "INSERT INTO commerce_authorized_users (user_id, approved_by_user_id) "
        "VALUES (9012, 9011)", "duplicate commerce approval is rejected"
    )
    expect_sql_failure(
        "INSERT INTO commerce_authorized_users (user_id, approved_by_user_id) "
        "VALUES (9013, 999999)", "commerce approver must be an existing user"
    )
    query(
        "INSERT INTO commerce_user_permissions "
        "(user_id, permission_code, granted_by_user_id) "
        "VALUES (9012, 'PRODUCTS_MANAGE', 9011)"
    )
    expect_sql_failure(
        "INSERT INTO commerce_user_permissions "
        "(user_id, permission_code, granted_by_user_id) "
        "VALUES (9012, 'PRODUCTS_MANAGE', 9011)",
        "duplicate personal permission rejected"
    )
    expect_sql_failure(
        "INSERT INTO commerce_user_permissions "
        "(user_id, permission_code, granted_by_user_id) "
        "VALUES (9013, 'PRODUCTS_MANAGE', 9011)",
        "cannot grant a permission to a non-approved person"
    )
    expect_sql_failure(
        "INSERT INTO commerce_user_permissions "
        "(user_id, permission_code, granted_by_user_id) "
        "VALUES (9012, 'ADMIN', 9011)",
        "cannot insert arbitrary permission codes"
    )
    query(
        "INSERT INTO commerce_role_permissions "
        "(role_id, permission_code, granted_by_user_id) "
        "VALUES (9011, 'PRODUCTS_MANAGE', 9011)"
    )
    expect_sql_failure(
        "INSERT INTO commerce_role_permissions "
        "(role_id, permission_code, granted_by_user_id) "
        "VALUES (9011, 'PRODUCTS_MANAGE', 9011)",
        "duplicate role permission rejected"
    )
    expect_sql_failure(
        "INSERT INTO commerce_role_permissions "
        "(role_id, permission_code, granted_by_user_id) "
        "VALUES (999999, 'PRODUCTS_MANAGE', 9011)",
        "commerce role permission must reference an existing Time role"
    )
    query(
        "INSERT INTO commerce_access_audit "
        "(actor_user_id, action, subject_user_id, permission_code) "
        "VALUES (9011, 'PERSON_PERMISSION_GRANTED', 9012, 'PRODUCTS_MANAGE')"
    )
    expect_sql_failure(
        "INSERT INTO commerce_access_audit (actor_user_id, action) "
        "VALUES (9011, 'UNKNOWN_OPERATION')",
        "commercial audit actions constrained"
    )
    query("DELETE FROM commerce_authorized_users WHERE user_id = 9012")
    require_equal(
        query("SELECT COUNT(*) FROM commerce_user_permissions WHERE user_id = 9012"),
        "0", "revoking approval cascades personal permission ceiling"
    )
    require_equal(
        query("SELECT COUNT(*) FROM commerce_access_audit WHERE subject_user_id = 9012"),
        "1", "audit survives person revocation"
    )
    query("DELETE FROM community_team_roles WHERE id = 9011")
    require_equal(
        query("SELECT COUNT(*) FROM commerce_role_permissions WHERE role_id = 9011"),
        "0", "deleting a Time role removes obsolete commercial role grants"
    )
    query("DELETE FROM commerce_access_audit")
    query("DELETE FROM community_team_roles WHERE id = 9012")
    query("DELETE FROM communities WHERE id IN (9011, 9012)")
    query("DELETE FROM users WHERE id IN (9011, 9012, 9013)")
    print("PASS: commercial access tables, FK, CHECK, revocation and audit")


def main() -> int:
    preflight_ok = False
    result = 0
    try:
        safety_preflight()
        preflight_ok = True
        down()
        start_empty_database()
        compose("run", "--rm", "flyway", "migrate")
        verify_access_tables()
        compose("run", "--rm", "flyway", "validate")
    except SmokeFailure as error:
        print(f"Commerce ACL smoke failed: {error}", file=sys.stderr)
        result = 1
    finally:
        if preflight_ok:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Teardown failed: {error}", file=sys.stderr)
                result = 1
    return result


if __name__ == "__main__":
    raise SystemExit(main())
