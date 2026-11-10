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
    query("INSERT INTO users(id,display_name) VALUES (99111,'Audit actor')")
    query("INSERT INTO communities (id,name) VALUES "
          "(99101,'Guild official'),(99102,'Other community')")
    query("INSERT INTO partners (id,name,status) VALUES "
          "(99101,'Partner A','active'),(99102,'Partner B','active')")
    query("INSERT INTO partner_discord_config (community_id,guild_id) "
          "VALUES (99101,123456789012345678)")
    query("INSERT INTO partner_discord_publications "
          "(partner_id,community_id,exclusive_channel_enabled,existing_text_channel_id) "
          "VALUES (99101,99101,1,999999999999999991)")
    require_equal(query("SELECT exclusive_channel_enabled FROM "
                        "partner_discord_publications WHERE partner_id=99101"),
                  "1", "exclusive channel request persisted")
    require_equal(query(
        "SELECT announcement_links_mode FROM partner_discord_publications "
        "WHERE partner_id=99101"
    ), "INLINE_ONLY", "existing partners default to inline links")
    require_equal(query(
        "SELECT announcement_part_message_ids FROM partner_discord_publications "
        "WHERE partner_id=99101"
    ), "[]", "existing publications have no continuation messages")
    query("SET NAMES utf8mb4; UPDATE partner_discord_publications SET "
          "announcement_markdown='# 🐑 República Indie\\nBem-vindos!', "
          "announcement_links_mode='APPEND_MISSING', "
          "announcement_public_contact='Contato: equipe Indie', "
          "announcement_part_message_ids='[\\\"123456789012345678\\\"]' "
          "WHERE partner_id=99101")
    require_equal(query(
        "SELECT announcement_links_mode FROM partner_discord_publications "
        "WHERE partner_id=99101"
    ), "APPEND_MISSING", "Markdown link mode persists")
    expect_sql_failure(
        "UPDATE partner_discord_publications SET announcement_links_mode='UNKNOWN' "
        "WHERE partner_id=99101",
        "invalid announcement link mode rejected")

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
        "INSERT INTO partner_discord_config (community_id,guild_id,thread_parent_channel_id) "
        "VALUES (99102,999999999999999991,888888888888888888)",
        "thread parent requires a category")
    expect_sql_failure(
        "INSERT INTO partner_discord_publications (partner_id,community_id,"
        "existing_text_channel_id) VALUES (99102,99101,999999999999999991)",
        "other partner cannot adopt an already-configured channel")
    expect_sql_failure(
        "DELETE FROM partners WHERE id=99101",
        "published partner cannot be removed without deprovisioning")
    require_equal(query("SELECT COUNT(*) FROM partner_discord_publications"),
                  "1", "existing publication preserved on rejected delete")
    query("INSERT INTO partner_discord_audit "
          "(community_id,partner_id,actor_user_id,action,details) "
          "VALUES (99101,99101,99111,'UNPUBLISHED','safe retirement')")
    query("DELETE FROM partner_discord_publications WHERE partner_id=99101")
    query("DELETE FROM partners WHERE id=99101")
    require_equal(query("SELECT COUNT(*) FROM partner_discord_audit "
                        "WHERE community_id=99101 AND partner_id IS NULL"), "1",
                  "audit retained after administrative partner deletion")
    print("PASS: empty schema, isolation, unique channels, safe unpublish and audit")


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
