#!/usr/bin/env python3
"""Disposable MariaDB proof of the Coddy voice XP audit expiry contract."""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure,
    assert_no_resources_remain,
    compose,
    down,
    query,
    require_equal,
    safety_preflight,
    start_empty_database,
)


def verify() -> None:
    require_equal(
        query(
            "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') "
            "FROM information_schema.STATISTICS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'voice_xp_audit_log' "
            "AND INDEX_NAME = 'idx_voice_xp_audit_retention'"
        ),
        "created_at,id",
        "Retention index covers chronological ordering",
    )

    query("""
        INSERT INTO voice_xp_audit_log
            (server_guild_id, discord_user_id, event_type, xp_amount, created_at)
        VALUES
            (90001, 90002, 'voice_xp_awarded', 2, CURRENT_TIMESTAMP - INTERVAL 74 HOUR),
            (90001, 90003, 'voice_xp_blocked_afk', 0, CURRENT_TIMESTAMP - INTERVAL 73 HOUR),
            (90001, 90004, 'voice_xp_awarded', 5, CURRENT_TIMESTAMP - INTERVAL 71 HOUR)
    """)
    query("""
        INSERT INTO voice_xp_daily_metrics
            (metric_day, server_guild_id, modality, voice_channel_id,
             total_xp, grants_count, blocks_count, eligible_seconds, ineligible_seconds)
        VALUES (CURRENT_DATE, 90001, 'voice_xp_awarded', 90011, 7, 2, 0, 120, 0)
    """)
    sql = """
        DELETE FROM voice_xp_audit_log
        WHERE created_at < CURRENT_TIMESTAMP - INTERVAL 72 HOUR
        ORDER BY created_at ASC, id ASC
        LIMIT 1
    """
    query(sql)
    require_equal(query("SELECT COUNT(*) FROM voice_xp_audit_log"), "2", "First batch deletes one row")
    query(sql)
    require_equal(query("SELECT COUNT(*) FROM voice_xp_audit_log"), "1", "Second batch deletes one row")
    query(sql)
    require_equal(query("SELECT COUNT(*) FROM voice_xp_audit_log"), "1", "Recent row remains")
    require_equal(
        query("SELECT discord_user_id FROM voice_xp_audit_log"),
        "90004",
        "72-hour retention protects recent audit details",
    )
    require_equal(
        query("SELECT total_xp FROM voice_xp_daily_metrics WHERE server_guild_id = 90001"),
        "7",
        "Daily aggregates remain unchanged",
    )
    print("PASS: index and bounded retention preserve recent audit rows and daily metrics")


def main() -> int:
    preflight = False
    result = 0
    try:
        safety_preflight()
        preflight = True
        down()
        start_empty_database()
        compose("run", "--rm", "flyway", "migrate")
        verify()
        compose("run", "--rm", "flyway", "validate")
    except SmokeFailure as error:
        print(f"Voice XP audit retention smoke failed: {error}", file=sys.stderr)
        result = 1
    finally:
        if preflight:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Teardown failed: {error}", file=sys.stderr)
                result = 1
    return result


if __name__ == "__main__":
    raise SystemExit(main())
