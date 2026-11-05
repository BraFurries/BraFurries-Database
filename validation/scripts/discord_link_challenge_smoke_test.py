#!/usr/bin/env python3
"""Exercise one-time Discord OAuth proof storage on isolated MariaDB only."""
from __future__ import annotations
import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight,
    start_empty_database,
)


def verify() -> None:
    query("INSERT INTO users (id,display_name) VALUES (99188,'OAuth owner')")
    query("INSERT INTO user_discord_link_challenges "
          "(ticket_hash,requesting_user_id,status,expires_at) "
          "VALUES (REPEAT('a',64),99188,'STARTED',DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE))")
    require_equal(query(
        "SELECT COUNT(*) FROM user_discord_link_challenges "
        "WHERE requesting_user_id=99188 AND status='STARTED'"), "1",
        "signed-in owner's one-time link proof persists")
    expect_sql_failure(
        "INSERT INTO user_discord_link_challenges "
        "(ticket_hash,requesting_user_id,status,expires_at) "
        "VALUES (REPEAT('a',64),99188,'STARTED',DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE))",
        "replayed ticket cannot be duplicated")
    expect_sql_failure(
        "INSERT INTO user_discord_link_challenges "
        "(ticket_hash,requesting_user_id,status,expires_at) "
        "VALUES (REPEAT('b',64),99189,'STARTED',DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE))",
        "owner must be a registered user")
    expect_sql_failure(
        "INSERT INTO user_discord_link_challenges "
        "(ticket_hash,requesting_user_id,status,expires_at) "
        "VALUES (REPEAT('c',64),99188,'UNVERIFIED',DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE))",
        "invalid challenge state must fail")
    query("UPDATE user_discord_link_challenges "
          "SET status='VERIFIED',discord_user_id=123456789012345678,"
          "discord_username='Furry',verified_at=UTC_TIMESTAMP() "
          "WHERE ticket_hash=REPEAT('a',64)")
    query("UPDATE user_discord_link_challenges "
          "SET status='CONSUMED',consumed_at=UTC_TIMESTAMP() "
          "WHERE ticket_hash=REPEAT('a',64)")
    require_equal(query(
        "SELECT COUNT(*) FROM user_discord_link_challenges "
        "WHERE status='CONSUMED' AND consumed_at IS NOT NULL"),"1",
        "OAuth proof may be consumed only after explicit confirmation")
    print("PASS: Discord proof ticket uniqueness, user FK, state constraints, consumption")


def main() -> int:
    passed_preflight = False
    status = 0
    try:
        safety_preflight()
        passed_preflight = True
        down()
        start_empty_database()
        compose("run", "--rm", "flyway", "migrate")
        verify()
        compose("run", "--rm", "flyway", "validate")
    except SmokeFailure as error:
        print(f"Discord account proof migration smoke failed: {error}", file=sys.stderr)
        status = 1
    finally:
        if passed_preflight:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Teardown failed: {error}", file=sys.stderr)
                status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
