#!/usr/bin/env python3
"""Disposable MariaDB smoke of commercial artist invitations and canonical ownership."""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down, expect_sql_failure,
    query, require_equal, safety_preflight, start_empty_database,
)


def verify() -> None:
    tables=("commerce_artist_profiles","commerce_artist_invitations","commerce_artist_consolidations")
    for table in tables:
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.TABLES "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}'"),
            "1",f"{table} exists")
        require_equal(query(f"SELECT COUNT(*) FROM {table}"),"0",f"{table} initially empty")
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}' "
            "AND COLUMN_NAME='community_id'"),
            "0",f"{table} is exclusively BraFurries")

    query("""
        INSERT INTO users (id,display_name) VALUES
            (99001,'Commercial administrator'),(99002,'External artist'),
            (99003,'Canonical account'),(99004,'Unknown account')
    """)
    query("""
        INSERT INTO commerce_artist_profiles
            (user_id,artist_name,telegram_handle,contact_email,created_by_user_id)
        VALUES (99002,'External Art','@artist','contact@example.invalid',99001)
    """)
    query("""
        INSERT INTO commerce_artist_invitations
            (id,artist_user_id,token_hash,code_hash,expires_at,issued_by_user_id)
        VALUES (999,99002,REPEAT('a',64),REPEAT('b',64),
                DATE_ADD(NOW(6), INTERVAL 2 DAY),99001)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_artist_invitations
            (artist_user_id,token_hash,code_hash,expires_at,issued_by_user_id)
        VALUES (99002,REPEAT('c',64),REPEAT('d',64),
                DATE_ADD(NOW(6), INTERVAL 2 DAY),99001)
    ""","at most one active invite for an artist")
    expect_sql_failure("""
        UPDATE commerce_artist_invitations SET status='USED' WHERE id=999
    ""","USED requires authenticated account and usage timestamp")
    expect_sql_failure("""
        UPDATE commerce_artist_invitations SET failed_attempts=6 WHERE id=999
    ""","failed confirmations capped at five")
    expect_sql_failure("""
        UPDATE commerce_artist_invitations SET status='REVOKED' WHERE id=999
    ""","revocation requires owner audit metadata")

    # Existing signed contracts must retain the original signatory, while
    # operational artist ownership may safely become the canonical user.
    require_equal(query("""
        SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA=DATABASE()
           AND TABLE_NAME='commerce_artwork_contracts'
           AND COLUMN_NAME='signed_artist_user_id'
           AND IS_NULLABLE='NO'
    """),"1","signed_artist_user_id is non-nullable historical evidence")
    require_equal(query("""
        SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
         WHERE CONSTRAINT_SCHEMA=DATABASE()
           AND TABLE_NAME='commerce_artwork_contracts'
           AND CONSTRAINT_NAME='fk_cac_artwork_only'
    """),"1","contract FK no longer blocks canonical artist transfer")

    query("""
        INSERT INTO commerce_contract_templates
            (id,name,modality,royalty_method,created_by_user_id)
        VALUES (99002,'Smoke one-time contract','ONE_TIME_FEE','NONE',99001)
    """)
    query("""
        INSERT INTO commerce_artworks
            (id,title,artist_user_id,creation_cost,created_by_user_id)
        VALUES (99002,'Artista externa',99002,100.00,99001)
    """)
    query("""
        INSERT INTO commerce_artwork_contracts
            (id,artwork_id,template_id,artist_user_id,signed_artist_user_id,
             modality_snapshot,royalty_method_snapshot,effective_from,
             signed_storage_key,signed_sha256,signed_bytes,created_by_user_id)
        VALUES (99002,99002,99002,99002,99002,
                'ONE_TIME_FEE','NONE','2026-11-09',
                'private/test/artist-contract',REPEAT('f',64),100,99001)
    """)
    query("""
        UPDATE commerce_artworks SET artist_user_id=99003 WHERE id=99002
    """)
    query("""
        UPDATE commerce_artwork_contracts SET artist_user_id=99003 WHERE id=99002
    """)
    require_equal(query("""
        SELECT COUNT(*) FROM commerce_artwork_contracts
         WHERE id=99002 AND artist_user_id=99003 AND signed_artist_user_id=99002
    """),"1","contract ownership moved while original signed party remains preserved")

    # The production executor transfers monthly lock rows by INSERT ... SELECT
    # against the same table. Test overlapping and distinct periods in MariaDB.
    query("""
        INSERT INTO commerce_period_locks
            (artist_user_id,period_year,period_month)
        VALUES (99002,2026,11),(99002,2026,12),(99003,2026,12)
    """)
    query("""
        INSERT IGNORE INTO commerce_period_locks
            (artist_user_id,period_year,period_month)
        SELECT 99003,period_year,period_month
          FROM commerce_period_locks WHERE artist_user_id=99002
    """)
    query("""
        DELETE FROM commerce_period_locks WHERE artist_user_id=99002
    """)
    require_equal(query("""
        SELECT COUNT(*) FROM commerce_period_locks
         WHERE artist_user_id=99003 AND period_year=2026
           AND period_month IN (11,12)
    """),"2","monthly mutex migration preserves both periods without duplicates")
    require_equal(query("""
        SELECT COUNT(*) FROM commerce_period_locks WHERE artist_user_id=99002
    """),"0","original commercial identity no longer owns period mutex rows")

    # MariaDB must reject overwriting a canonical settlement in the same
    # period; the API performs this conflict preflight before any writes.
    query("""
        INSERT INTO commerce_settlements
            (artist_user_id,period_year,period_month,total_amount,created_by_user_id)
        VALUES (99002,2026,11,50.00,99001),(99003,2026,11,30.00,99001)
    """)
    expect_sql_failure("""
        UPDATE commerce_settlements SET artist_user_id=99003
         WHERE artist_user_id=99002 AND period_year=2026 AND period_month=11
    ""","conflicting period settlements cannot be merged blindly")

    query("""
        UPDATE commerce_artist_invitations
           SET status='USED',consumed_by_user_id=99003,consumed_at=NOW(6)
         WHERE id=999
    """)
    query("""
        UPDATE commerce_artist_profiles SET user_id=99003 WHERE user_id=99002
    """)
    query("""
        INSERT INTO commerce_artist_consolidations
            (invitation_id,original_user_id,canonical_user_id,
             consolidation_kind,artworks_moved,contracts_moved)
        VALUES (999,99002,99003,'MERGE',1,1)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_artist_consolidations
            (invitation_id,original_user_id,canonical_user_id,consolidation_kind)
        VALUES (999,99002,99004,'MERGE')
    ""","duplicate invite cannot be redeemed twice")
    print("PASS: staff-only invite constraints and preserved signed contract attribution")


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
        print(f"Commerce artist invitation smoke failed: {error}",file=sys.stderr)
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
