#!/usr/bin/env python3
"""Disposable MariaDB/Flyway validation for append-only commercial corrections."""
from __future__ import annotations
import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight, start_empty_database
)

TABLES = (
    "commerce_production_batch_revisions",
    "commerce_payment_metadata_revisions",
    "commerce_cash_metadata_revisions",
)

def verify() -> None:
    for table in TABLES:
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.TABLES "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}'"
        ), "1", f"{table} exists")
        require_equal(query(f"SELECT COUNT(*) FROM {table}"), "0",
                      f"{table} starts empty")
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}' "
            "AND COLUMN_NAME='community_id'"
        ), "0", "commercial corrections never expose Community tenancy")
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.TRIGGERS "
            f"WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE='{table}' "
            "AND EVENT_MANIPULATION IN ('UPDATE','DELETE') "
            "AND ACTION_TIMING='BEFORE'"
        ), "2", f"{table} has immutable UPDATE and DELETE guards")

    query("""
        INSERT INTO users(id,display_name)
        VALUES (98001,'Commercial admin'),(98002,'External artist')
    """)
    query("""
        INSERT INTO commerce_suppliers(id,name,created_by_user_id)
        VALUES (98001,'Test supplier',98001)
    """)
    query("""
        INSERT INTO commerce_products(id,sku,name,suggested_price,created_by_user_id)
        VALUES (98001,'REV-SKU-98001','Test shirt',60.00,98001)
    """)
    query("""
        INSERT INTO commerce_production_batches
            (id,product_id,supplier_id,quantity,unit_cost,additional_cost,
             total_cost,produced_on,reference,created_by_user_id)
        VALUES (98001,98001,98001,3,10,0,30,'2026-11-02','PREV',98001)
    """)
    query("""
        INSERT INTO commerce_production_batch_revisions
            (batch_id,before_json,after_json,reason,actor_user_id)
        VALUES (98001,'{"reference":"PREV"}','{"reference":"NEXT"}',
                'Erro de digitação',98001)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_production_batch_revisions
            (batch_id,before_json,after_json,reason,actor_user_id)
        VALUES (98001,'not JSON','{"reference":"NEXT"}','Motivo válido',98001)
    ""","batch revision requires valid JSON")
    require_equal(query("""
        SELECT JSON_VALID(JSON_OBJECT(
            'productId',product_id,'supplierId',supplier_id,
            'quantity',quantity,'unitCost',unit_cost,
            'additionalCost',additional_cost,'totalCost',total_cost,
            'producedOn',produced_on,'reference',reference,
            'soldQuantity',sold_quantity))
        FROM commerce_production_batches WHERE id=98001
    """),"1","API production lot before/after snapshot is MariaDB-valid JSON")
    expect_sql_failure("""
        UPDATE commerce_production_batch_revisions SET reason='Changed' WHERE batch_id=98001
    ""","batch evidence is append-only")
    expect_sql_failure("""
        DELETE FROM commerce_production_batch_revisions WHERE batch_id=98001
    ""","batch evidence cannot be deleted")

    query("""
        INSERT INTO commerce_settlements
            (id,artist_user_id,period_year,period_month,total_amount,created_by_user_id)
        VALUES (98001,98002,2026,11,15.00,98001)
    """)
    query("""
        INSERT INTO commerce_payments
            (id,settlement_id,request_key,amount,paid_on,external_reference,
             recorded_by_user_id)
        VALUES (98001,98001,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
                15.00,'2026-11-02','BANK-1',98001)
    """)
    query("""
        INSERT INTO commerce_payment_metadata_revisions
            (payment_id,previous_reference,updated_reference,
             previous_notes,updated_notes,reason,actor_user_id)
        VALUES (98001,'BANK-1','BANK-2',NULL,'Corrigido',
                'Referência bancária digitada incorretamente',98001)
    """)
    expect_sql_failure("""
        UPDATE commerce_payment_metadata_revisions
           SET updated_reference='BANK-3' WHERE payment_id=98001
    ""","payout correction history is append-only")
    expect_sql_failure("""
        DELETE FROM commerce_payment_metadata_revisions WHERE payment_id=98001
    ""","payout corrections cannot disappear")
    require_equal(query("""
        SELECT external_reference FROM commerce_payments WHERE id=98001
    """),"BANK-1","original payout remains immutable")
    require_equal(query("""
        SELECT updated_reference
          FROM commerce_payment_metadata_revisions WHERE payment_id=98001
    """),"BANK-2","new reference is visible in revision table")
    require_equal(query("""
        SELECT CASE WHEN r.id IS NULL THEN p.external_reference
                    ELSE r.updated_reference END
          FROM commerce_payments p
          LEFT JOIN commerce_payment_metadata_revisions r
            ON r.id=(SELECT MAX(latest.id)
                       FROM commerce_payment_metadata_revisions latest
                      WHERE latest.payment_id=p.id)
         WHERE p.id=98001
    """),"BANK-2","API payment listing projects latest corrected reference")
    require_equal(query("""
        SELECT p.id FROM commerce_payments p
          LEFT JOIN commerce_payment_metadata_revisions r
            ON r.id=(SELECT MAX(latest.id)
                       FROM commerce_payment_metadata_revisions latest
                      WHERE latest.payment_id=p.id)
         WHERE p.settlement_id=98001 AND p.id<>999999
           AND (CASE WHEN r.id IS NULL THEN p.external_reference
                     ELSE r.updated_reference END)='BANK-2'
         LIMIT 1 FOR UPDATE
    """),"98001","API payment uniqueness check supports locking join")
    require_equal(query("""
        SELECT updated_reference
          FROM commerce_payment_metadata_revisions
         WHERE payment_id=98001 ORDER BY id DESC LIMIT 1 FOR UPDATE
    """),"BANK-2","API reads latest revision with a locking read")

    query("""
        INSERT INTO commerce_cash_movements
            (id,request_key,request_sha256,movement_type,amount,occurred_on,
             category,description,counterparty_label,payment_method,created_by_user_id)
        VALUES (98001,'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'EXPENSE',20,'2026-11-02','MATERIAL','Impressão','Gráfica',
                'PIX',98001)
    """)
    query("""
        INSERT INTO commerce_cash_metadata_revisions
            (movement_id,previous_description,updated_description,
             previous_reference,updated_reference,previous_notes,updated_notes,
             reason,actor_user_id)
        VALUES (98001,'Impressão','Impressão de cartazes',
                NULL,'NOTA-123',NULL,'Confirmação', 'Descrição corrigida',98001)
    """)
    expect_sql_failure("""
        UPDATE commerce_cash_metadata_revisions
           SET updated_description='Outra' WHERE movement_id=98001
    ""","cash correction history is append-only")
    expect_sql_failure("""
        DELETE FROM commerce_cash_metadata_revisions WHERE movement_id=98001
    ""","cash correction history is preserved")
    require_equal(query("""
        SELECT description FROM commerce_cash_movements WHERE id=98001
    """),"Impressão","original expense stays untouched")
    require_equal(query("""
        SELECT COUNT(*) FROM commerce_cash_metadata_revisions WHERE movement_id=98001
    """),"1","cash correction is recorded exactly once")
    require_equal(query("""
        SELECT CASE WHEN r.id IS NULL THEN m.description
                    ELSE r.updated_description END
          FROM commerce_cash_movements m
          LEFT JOIN commerce_cash_metadata_revisions r
            ON r.id=(SELECT MAX(latest.id)
                       FROM commerce_cash_metadata_revisions latest
                      WHERE latest.movement_id=m.id)
         WHERE m.id=98001
    """),"Impressão de cartazes","API cash listing projects latest corrected description")
    print("PASS: operational corrections append-only and original financial rows intact")

def main() -> int:
    preflight = False
    result = 0
    try:
        safety_preflight()
        preflight = True
        down()
        start_empty_database()
        compose("run","--rm","flyway","migrate")
        verify()
        compose("run","--rm","flyway","validate")
    except SmokeFailure as error:
        print(f"Commerce metadata revision smoke failed: {error}",file=sys.stderr)
        result = 1
    finally:
        if preflight:
            down()
            try: assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Teardown failed: {error}",file=sys.stderr)
                result = 1
    return result

if __name__ == "__main__":
    raise SystemExit(main())
