#!/usr/bin/env python3
"""Verify partner Discord state on disposable MariaDB only (never production)."""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight, start_empty_database,
)


def verify() -> None:
    for table in ("partner_discord_config", "partner_discord_publications"):
        require_equal(query(f"SELECT COUNT(*) FROM {table}"), "0",
                      f"{table} starts empty")
    query("INSERT INTO communities (id,name) VALUES "
          "(99101,'Guild official'),(99102,'Other community')")
    query("INSERT INTO partners (id,name,status) VALUES "
          "(99101,'Partner A','active'),(99102,'Partner B','active')")
    query("INSERT INTO partner_discord_config (community_id,guild_id) "
          "VALUES (99101,123456789012345678)")
    query("INSERT INTO partner_discord_publications "
          "(partner_id,community_id,exclusive_channel_enabled) "
          "VALUES (99101,99101,1)")
    require_equal(query("SELECT exclusive_channel_enabled FROM "
                        "partner_discord_publications WHERE partner_id=99101"),
                  "1", "exclusive channel request persisted")
    expect_sql_failure(
        "INSERT INTO partner_discord_config (community_id,guild_id) "
        "VALUES (99102,123456789012345678)",
        "same Discord guild cannot be configured twice")
    expect_sql_failure(
        "INSERT INTO partner_discord_publications (partner_id,community_id) "
        "VALUES (99102,99102)",
        "publication must belong to configured community")
    expect_sql_failure(
        "UPDATE partner_discord_publications "
        "SET exclusive_channel_enabled=2 WHERE partner_id=99101",
        "invalid boolean is rejected")
    expect_sql_failure(
        "UPDATE partner_discord_publications SET applied_revision=2 "
        "WHERE partner_id=99101",
        "applied revision cannot exceed desired revision")
    expect_sql_failure(
        "DELETE FROM partners WHERE id=99101",
        "published partner cannot be removed without deprovisioning")
    require_equal(query("SELECT COUNT(*) FROM partner_discord_publications"),
                  "1", "existing publication preserved on rejected delete")
    print("PASS: empty schema, guild isolation, FKs, revision and deletion safety")


def main() -> int:
    preflight = False
    status = 0
    try:
        safety_preflight()
        preflight = True
        down()
        start_empty_database()
        compose("run", "--rm", "flyway", "migrate")
        verify()
        compose("run", "--rm", "flyway", "validate")
    except SmokeFailure as error:
        print(f"Partner Discord smoke failed: {error}", file=sys.stderr)
        status = 1
    finally:
        if preflight:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Teardown failed: {error}", file=sys.stderr)
                status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
