#!/usr/bin/env python3
"""Disposable MariaDB validation of private commerce artist ownership claims."""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down, expect_sql_failure,
    query, require_equal, safety_preflight, start_empty_database,
)


def verify() -> None:
    for table in ("commerce_artist_profiles", "commerce_artist_claim_requests"):
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.TABLES "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}'"),
            "1", f"{table} exists")
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}' "
            "AND COLUMN_NAME='community_id'"),
            "0", f"{table} is BraFurries-only")
        require_equal(query(f"SELECT COUNT(*) FROM {table}"),
            "0", f"{table} starts empty")

    query("""
        INSERT INTO users (id,display_name) VALUES
        (99001,'Owner'),(99002,'External artist'),(99003,'Applicant'),
        (99004,'Second applicant')
    """)
    query("""
        INSERT INTO commerce_artist_profiles
            (user_id,artist_name,telegram_handle,contact_email,created_by_user_id)
        VALUES (99002,'External Art','@artist','not_verified@example.invalid',99001)
    """)
    require_equal(query("""
        SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users'
           AND COLUMN_NAME IN ('email','password_hash')
    """),"2","users login credential columns remain present")
    require_equal(query("""
        SELECT COUNT(*) FROM `users`
         WHERE `id`=99002 AND `email` IS NULL AND `password_hash` IS NULL
    """),"1","commercial artist is not a login credential")
    expect_sql_failure("""
        INSERT INTO commerce_artist_profiles (user_id,artist_name,created_by_user_id)
        VALUES (99003,'',99001)
    ""","empty artist names prohibited")
    expect_sql_failure("""
        INSERT INTO commerce_artist_profiles (user_id,artist_name,created_by_user_id)
        VALUES (99999,'Phantom',99001)
    ""","artist profile requires real users.id")

    query("""
        INSERT INTO commerce_artist_claim_requests
            (artist_user_id,requester_user_id,requester_message)
        VALUES (99002,99003,'Please verify using existing artist contact')
    """)
    expect_sql_failure("""
        INSERT INTO commerce_artist_claim_requests
            (artist_user_id,requester_user_id)
        VALUES (99002,99004)
    ""","only one active request per commercial artist")
    expect_sql_failure("""
        INSERT INTO commerce_artist_claim_requests
            (artist_user_id,requester_user_id,status)
        VALUES (99002,99004,'APPROVED')
    ""","claim approval requires a named reviewer")
    expect_sql_failure("""
        UPDATE commerce_artist_profiles
           SET claimed_by_user_id=99003 WHERE user_id=99002
    ""","cannot activate ownership without approval metadata")

    query("""
        UPDATE commerce_artist_claim_requests
           SET status='APPROVED',verification_method='TELEGRAM',
               reviewed_by_user_id=99001,reviewed_at=CURRENT_TIMESTAMP(6)
         WHERE artist_user_id=99002 AND requester_user_id=99003
    """)
    query("""
        UPDATE commerce_artist_profiles
           SET claimed_by_user_id=99003,claimed_at=CURRENT_TIMESTAMP(6),
               claim_approved_by_user_id=99001 WHERE user_id=99002
    """)
    require_equal(query("""
        SELECT COUNT(*) FROM commerce_artist_profiles
         WHERE user_id=99002 AND claimed_by_user_id=99003
    """),"1","approved claim points to website user while artist data stays on original users.id")
    expect_sql_failure("""
        UPDATE commerce_artist_profiles SET claimed_by_user_id=99002
         WHERE user_id=99002
    ""","artist placeholder cannot self claim")
    require_equal(query("""
        SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
         WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='commerce_royalty_accruals'
           AND COLUMN_NAME='artist_user_id' AND REFERENCED_TABLE_NAME='users'
    """),"1","legacy royalty FK unchanged")

    print("PASS: commerce artist identity, claim uniqueness, approval integrity, and historical FK")


def main() -> int:
    preflight=False
    status=0
    try:
        safety_preflight()
        preflight=True
        down()
        start_empty_database()
        compose("run","--rm","flyway","migrate")
        verify()
        compose("run","--rm","flyway","validate")
    except SmokeFailure as error:
        print(f"Commerce artist claim smoke failed: {error}",file=sys.stderr)
        status=1
    finally:
        if preflight:
            down()
            try: assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Teardown failed: {error}",file=sys.stderr)
                status=1
    return status


if __name__=="__main__":
    raise SystemExit(main())
