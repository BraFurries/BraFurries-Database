#!/usr/bin/env python3
"""Validate social-account reconciliation schema on an isolated MariaDB container."""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight,
    start_empty_database,
)


def verify() -> None:
    query("INSERT INTO users (id,display_name) VALUES "
          "(99210,'Legacy Discord'),(99211,'Google member'),(99212,'Independent')")
    query("INSERT INTO user_discord (user_id,discord_user_id,username) "
          "VALUES (99210,992100100100,'old_discord')")
    query("INSERT INTO user_social_identities "
          "(user_id,provider,provider_subject,verified_email) VALUES "
          "(99211,'google','google-sub-99211','google@example.org')")
    expect_sql_failure(
        "INSERT INTO user_social_identities "
        "(user_id,provider,provider_subject) "
        "VALUES (99212,'google','google-sub-99211')",
        "the same verified Google subject cannot belong to different users",
    )
    # A verified user may control several Discord/Google subjects. Their
    # provider+subject pair remains globally unique across all users.
    query("INSERT INTO user_social_identities "
          "(user_id,provider,provider_subject) VALUES "
          "(99211,'google','another-google-sub'),"
          "(99211,'discord','discord-alt-99211'),"
          "(99211,'discord','discord-main-99211')")
    require_equal(query("SELECT COUNT(*) FROM user_social_identities WHERE user_id=99211"),
                  "4", "multiple provider subjects may resolve to one functional user")
    expect_sql_failure(
        "INSERT INTO user_social_identities "
        "(user_id,provider,provider_subject) "
        "VALUES (99212,'unknown','untrusted-sub')",
        "unknown OAuth providers are not valid",
    )
    # OAuth challenge uniqueness and replay protection belong to Database #47.
    query("UPDATE users SET merged_into_user_id=99210 WHERE id=99211")
    query("INSERT INTO user_account_consolidations "
          "(canonical_user_id,absorbed_user_id,proved_discord_user_id,initiated_by_user_id) "
          "VALUES (99210,99211,992100100100,99211)")
    require_equal(query("SELECT COUNT(*) FROM user_account_consolidations "
                        "WHERE canonical_user_id=99210 AND absorbed_user_id=99211"),
                  "1", "historical merge is audit-traceable")
    require_equal(query("SELECT merged_into_user_id FROM users WHERE id=99211"),
                  "99210", "absorbed account cannot keep a separate login identity")
    # API will reject self-links before touching a row; MariaDB cannot CHECK
    # AUTO_INCREMENT primary keys inside the same table.
    expect_sql_failure(
        "INSERT INTO user_account_consolidations "
        "(canonical_user_id,absorbed_user_id,proved_discord_user_id,initiated_by_user_id) "
        "VALUES (99212,99211,992100100100,99211)",
        "the same account cannot be consolidated twice",
    )
    print("PASS: global OAuth subject uniqueness, multiple provider subjects, audited aliases")


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
        print(f"Social account reconciliation smoke failed: {ex}", file=sys.stderr)
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
