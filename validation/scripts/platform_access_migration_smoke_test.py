#!/usr/bin/env python3
"""Exercise real legacy commerce access -> platform access migration on disposable MariaDB.

Never contacts a production/shared datasource. Verify approvals, audit and role
grants survive the atomic RENAME TABLE; there must be no second authority.
"""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight,
    start_empty_database,
)


def verify() -> None:
    require_equal(query("SELECT COUNT(*) FROM platform_authorized_users WHERE user_id=99152"),
                  "1", "owner-approved person preserved")
    require_equal(query("SELECT COUNT(*) FROM platform_user_permissions "
                        "WHERE user_id=99152 AND permission_code='FINANCE_VIEW'"),
                  "1", "finance individual grant preserved")
    require_equal(query("SELECT COUNT(*) FROM platform_role_permissions "
                        "WHERE role_id=99151 AND permission_code='FINANCE_VIEW'"),
                  "1", "finance role grant preserved")
    require_equal(query("SELECT COUNT(*) FROM platform_access_audit "
                        "WHERE subject_user_id=99152 AND action='PERSON_PERMISSION_GRANTED'"),
                  "1", "historical immutable audit preserved")
    require_equal(query("SELECT COUNT(*) FROM platform_permission_catalog"), "10",
                  "canonical platform permission catalog")
    for name in ("commerce_authorized_users", "commerce_user_permissions",
                 "commerce_role_permissions", "commerce_access_audit"):
        require_equal(query("SELECT COUNT(*) FROM information_schema.TABLES "
                            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{name}'"),
                      "0", "legacy ACL table cannot remain an authority")
    query("INSERT INTO platform_user_permissions "
          "(user_id,permission_code,granted_by_user_id) "
          "VALUES (99152,'PARTNERS_MANAGE',99151)")
    expect_sql_failure(
        "INSERT INTO platform_user_permissions "
        "(user_id,permission_code,granted_by_user_id) "
        "VALUES (99152,'UNREGISTERED',99151)",
        "unregistered permissions must fail FK"
    )
    query("DELETE FROM platform_authorized_users WHERE user_id=99152")
    require_equal(query("SELECT COUNT(*) FROM platform_user_permissions WHERE user_id=99152"),
                  "0", "revoking person cascades all platform grants")
    require_equal(query("SELECT COUNT(*) FROM platform_access_audit WHERE subject_user_id=99152"),
                  "1", "historical audit survives revocation")
    print("PASS: migrated finance grants and audit, canonical catalog and cascades")


def main() -> int:
    preflight_ok = False
    status = 0
    try:
        safety_preflight()
        preflight_ok = True
        down()
        start_empty_database()
        # Match production: 002 may already be applied by the user.
        compose("run", "--rm", "flyway", "-target=20261104.002", "migrate")
        query("INSERT INTO users (id,display_name) VALUES "
              "(99151,'Access owner'),(99152,'Finance manager')")
        query("INSERT INTO communities (id,name) VALUES (99151,'BraFurries isolated')")
        query("INSERT INTO community_team_roles (id,community_id,name,active) "
              "VALUES (99151,99151,'Finance role',1)")
        query("INSERT INTO commerce_authorized_users (user_id,approved_by_user_id) "
              "VALUES (99152,99151)")
        query("INSERT INTO commerce_user_permissions "
              "(user_id,permission_code,granted_by_user_id) "
              "VALUES (99152,'FINANCE_VIEW',99151)")
        query("INSERT INTO commerce_role_permissions "
              "(role_id,permission_code,granted_by_user_id) "
              "VALUES (99151,'FINANCE_VIEW',99151)")
        query("INSERT INTO commerce_access_audit "
              "(actor_user_id,action,subject_user_id,permission_code) "
              "VALUES (99151,'PERSON_PERMISSION_GRANTED',99152,'FINANCE_VIEW')")
        compose("run", "--rm", "flyway", "migrate")
        compose("run", "--rm", "flyway", "validate")
        verify()
    except SmokeFailure as error:
        print(f"Platform ACL migration smoke failed: {error}", file=sys.stderr)
        status = 1
    finally:
        if preflight_ok:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Teardown failed: {error}", file=sys.stderr)
                status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
