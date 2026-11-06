#!/usr/bin/env python3
"""Audit immutable one-sided Community membership transfer on disposable MariaDB."""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight,
    start_empty_database,
)


def verify() -> None:
    query("INSERT INTO users (id,display_name) VALUES "
          "(99510,'Proven website'),(99511,'Proven Discord')")
    query("INSERT INTO communities (id,name) VALUES "
          "(99501,'Community A'),(99502,'Community B')")
    query("INSERT INTO user_community_status "
          "(id,user_id,community_id,member_since,approved,is_vip,is_partner,banned,"
          "birthday_mentionable) VALUES "
          "(99520,99510,99501,'2024-01-01 08:00:00',b'1',b'0',b'0',b'0',0)")
    query("INSERT INTO user_account_consolidations "
          "(id,canonical_user_id,absorbed_user_id,proved_discord_user_id,initiated_by_user_id) "
          "VALUES (99530,99511,99510,995100000001,99510)")
    query("UPDATE user_community_status SET user_id=99511 WHERE id=99520")
    query("INSERT INTO user_community_membership_transfers "
          "(consolidation_id,community_status_id,community_id,from_user_id,to_user_id) "
          "VALUES (99530,99520,99501,99510,99511)")
    require_equal(query("SELECT COUNT(*) FROM user_community_membership_transfers "
                        "WHERE consolidation_id=99530 AND community_id=99501 "
                        "AND from_user_id=99510 AND to_user_id=99511"),
                  "1", "each membership transfer must be tenant- and identity-traceable")
    require_equal(query("SELECT user_id FROM user_community_status WHERE id=99520"),
                  "99511", "Community membership row retains its original ID")
    expect_sql_failure(
        "INSERT INTO user_community_membership_transfers "
        "(consolidation_id,community_status_id,community_id,from_user_id,to_user_id) "
        "VALUES (99530,99520,99501,99510,99511)",
        "duplicate transfer of the same membership within one consolidation")
    expect_sql_failure(
        "INSERT INTO user_community_membership_transfers "
        "(consolidation_id,community_status_id,community_id,from_user_id,to_user_id) "
        "VALUES (99530,99520,99501,99510,99510)",
        "a membership cannot transfer from an account into itself")
    expect_sql_failure(
        "INSERT INTO user_community_membership_transfers "
        "(consolidation_id,community_status_id,community_id,from_user_id,to_user_id) "
        "VALUES (99530,99520,999999,99510,99511)",
        "audit cannot point to a nonexistent Community")
    print("PASS: immutable Community transfer audit, uniqueness, FK and provenance")


def main() -> int:
    preflight = False
    status = 0
    try:
        safety_preflight()
        preflight = True
        down()
        start_empty_database()
        compose("run", "--rm", "flyway", "migrate")
        compose("run", "--rm", "flyway", "validate")
        verify()
    except SmokeFailure as ex:
        print(f"Membership consolidation audit failed: {ex}", file=sys.stderr)
        status = 1
    finally:
        if preflight:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as ex:
                print(f"Teardown failed: {ex}", file=sys.stderr)
                status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
