#!/usr/bin/env python3
"""Verify the additive partner-link migration using local disposable MariaDB only."""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight,
    start_empty_database,
)


def verify() -> None:
    require_equal(query("SELECT COUNT(*) FROM partners WHERE id=97001"), "1",
                  "legacy partner is preserved")
    require_equal(query("SELECT COUNT(*) FROM partner_external_links WHERE id=97001"),
                  "1", "legacy external link remains")
    require_equal(query("SELECT is_primary FROM partner_external_links WHERE id=97001"),
                  "0", "legacy link defaults to non-primary")
    require_equal(query(
        "SELECT COUNT(*) FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='partner_external_links' "
        "AND INDEX_NAME='uq_partner_external_links_one_primary'"
    ), "1", "one-primary unique index exists")

    query("INSERT INTO partner_external_links (partner_id,type,url) "
          "VALUES (97001,'website','https://example.org')")
    query("UPDATE partner_external_links SET is_primary=1 WHERE id=97001")
    expect_sql_failure(
        "UPDATE partner_external_links SET is_primary=1 "
        "WHERE partner_id=97001 AND id<>97001",
        "cannot mark two links primary for the same partner",
    )
    query("INSERT INTO partners (id,name,status) VALUES (97002,'Outro parceiro','active')")
    query("INSERT INTO partner_external_links (partner_id,type,url,is_primary) "
          "VALUES (97002,'website','https://outro.example',1)")
    require_equal(query(
        "SELECT COUNT(*) FROM partner_external_links WHERE is_primary=1"
    ), "2", "independent partners may each have one primary link")
    expect_sql_failure(
        "UPDATE partner_external_links SET is_primary=2 WHERE id=97001",
        "invalid boolean values are rejected",
    )
    print("PASS: legacy links, single primary, independent partner and CHECK")


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
        print(f"Partner primary-link smoke failed: {error}", file=sys.stderr)
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
