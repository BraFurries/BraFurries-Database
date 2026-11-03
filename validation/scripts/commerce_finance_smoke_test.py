#!/usr/bin/env python3
"""Disposable MariaDB/Flyway checks of BraFurries private commerce ledger."""
from __future__ import annotations
import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight, start_empty_database
)

TABLES=(
    "commerce_period_locks", "commerce_sales", "commerce_sale_items",
    "commerce_royalty_accruals", "commerce_settlements",
    "commerce_settlement_items", "commerce_payments", "commerce_finance_audit"
)

def verify() -> None:
    for table in TABLES:
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.TABLES "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}'"),
            "1", f"{table} exists")
        require_equal(query(f"SELECT COUNT(*) FROM {table}"),
            "0", f"{table} begins empty")
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}' "
            "AND COLUMN_NAME='community_id'"),
            "0", f"{table} is not a Community tenant")

    query("""
        INSERT INTO users (id,display_name) VALUES
        (95001,'Director'),(95002,'Artist')
    """)
    query("""
        INSERT INTO commerce_period_locks
            (artist_user_id,period_year,period_month)
        VALUES (95002,2026,11)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_period_locks
            (artist_user_id,period_year,period_month)
        VALUES (95002,2026,13)
    """, "invalid accounting period rejected")

    query("""
        INSERT INTO commerce_suppliers (id,name,created_by_user_id)
        VALUES (95001,'Finance fixture supplier',95001)
    """)
    query("""
        INSERT INTO commerce_products
            (id,sku,name,suggested_price,created_by_user_id)
        VALUES (95001,'FINANCE-95001','Fixture mug',60.00,95001)
    """)
    query("""
        INSERT INTO commerce_production_batches
            (id,product_id,supplier_id,quantity,unit_cost,
             additional_cost,total_cost,produced_on,created_by_user_id)
        VALUES (95001,95001,95001,10,25.00,0,250.00,'2026-11-03',95001)
    """)
    query("""
        INSERT INTO commerce_sales
            (id,request_key,request_sha256,channel,external_reference,
             sold_on,gross_amount,created_by_user_id)
        VALUES (95001,'11111111-1111-4111-8111-111111111111',
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'EVENT','ORDER-95001','2026-11-03',120.00,95001)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_sales
            (request_key,request_sha256,channel,external_reference,
             sold_on,gross_amount,created_by_user_id)
        VALUES ('11111111-1111-4111-8111-111111111111',
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'EVENT','ORDER-95002','2026-11-03',60.00,95001)
    """, "duplicate retry key rejected")
    expect_sql_failure("""
        INSERT INTO commerce_sales
            (request_key,request_sha256,channel,external_reference,
             sold_on,gross_amount,created_by_user_id)
        VALUES ('22222222-2222-4222-8222-222222222222',
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                'EVENT','ORDER-95001','2026-11-03',60.00,95001)
    """, "same external channel and reference rejected")
    query("""
        INSERT INTO commerce_sale_items
            (id,sale_id,product_id,production_batch_id,quantity,
             unit_price_snapshot,line_gross_amount,line_production_cost_snapshot)
        VALUES (95001,95001,95001,95001,2,60.00,120.00,50.00)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_sale_items
            (sale_id,product_id,production_batch_id,quantity,
             unit_price_snapshot,line_gross_amount,line_production_cost_snapshot)
        VALUES (95001,95001,95001,1,60.00,60.00,25.00)
    """, "duplicate batch in same sale is rejected")
    expect_sql_failure("""
        INSERT INTO commerce_sale_items
            (sale_id,product_id,production_batch_id,quantity,
             unit_price_snapshot,line_gross_amount,line_production_cost_snapshot)
        VALUES (95001,95001,95001,2,60.00,119.99,50.00)
    """, "line price cannot contradict snapshot")
    query("""
        INSERT INTO commerce_contract_templates
            (id,name,modality,royalty_method,royalty_percent,created_by_user_id)
        VALUES (95001,'Finance fixture license','ROYALTY','PERCENT_GROSS',10,95001)
    """)
    query("""
        INSERT INTO commerce_artworks
            (id,title,artist_user_id,created_by_user_id)
        VALUES (95001,'Fixture art',95002,95001)
    """)
    query("""
        INSERT INTO commerce_artwork_contracts
            (id,artwork_id,template_id,artist_user_id,modality_snapshot,
             royalty_method_snapshot,royalty_percent_snapshot,effective_from,
             signed_storage_key,signed_sha256,signed_bytes,created_by_user_id)
        VALUES (95001,95001,95001,95002,'ROYALTY','PERCENT_GROSS',10,
            '2026-11-03','commerce/contracts/95001/test.pdf',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            20,95001)
    """)
    query("""
        INSERT INTO commerce_royalty_accruals
            (id,sale_item_id,artwork_id,contract_id,artist_user_id,period_year,
             period_month,event_kind,royalty_method_snapshot,
             contract_rate_snapshot,allocation_percent_snapshot,
             basis_amount_snapshot,amount)
        VALUES (95001,95001,95001,95001,95002,2026,11,'SALE',
                'PERCENT_GROSS',10.0000,100.0000,120.00,12.00)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_royalty_accruals
            (sale_item_id,artwork_id,contract_id,artist_user_id,period_year,
             period_month,event_kind,royalty_method_snapshot,
             contract_rate_snapshot,allocation_percent_snapshot,
             basis_amount_snapshot,amount)
        VALUES (95001,95001,95001,95002,2026,11,'REVERSAL',
                'PERCENT_GROSS',10.0000,100.0000,120.00,-12.00)
    """, "a reversal always needs an origin reference")
    query("""
        INSERT INTO commerce_royalty_accruals
            (sale_item_id,artwork_id,contract_id,artist_user_id,period_year,
             period_month,event_kind,original_accrual_id,royalty_method_snapshot,
             contract_rate_snapshot,allocation_percent_snapshot,basis_amount_snapshot,amount)
        VALUES (95001,95001,95001,95002,2026,11,'REVERSAL',95001,
                'PERCENT_GROSS',10,100,120,-12.00)
    """)
    require_equal(query("""
        SELECT SUM(amount) FROM commerce_royalty_accruals
         WHERE artist_user_id=95002 AND period_year=2026 AND period_month=11
    """),"0.00","compensation balances the original accrual without erasure")
    query("""
        INSERT INTO commerce_settlements
            (id,artist_user_id,period_year,period_month,total_amount,created_by_user_id)
        VALUES (95001,95002,2026,11,0,95001)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_settlements
            (artist_user_id,period_year,period_month,total_amount,created_by_user_id)
        VALUES (95002,2026,11,0,95001)
    """, "only one monthly statement per artist")
    query("""
        INSERT INTO commerce_settlement_items
            (settlement_id,accrual_id,amount_snapshot)
        VALUES (95001,95001,12.00)
    """)
    expect_sql_failure("""
        INSERT INTO commerce_settlement_items
            (settlement_id,accrual_id,amount_snapshot)
        VALUES (95001,95001,12.00)
    """, "one statement item per accrual")
    expect_sql_failure("""
        INSERT INTO commerce_payments
            (settlement_id,request_key,amount,paid_on,external_reference,recorded_by_user_id)
        VALUES (95001,'33333333-3333-4333-8333-333333333333',0,
                '2026-11-03','PAY-95001',95001)
    """, "payment requires a positive amount")
    query("""
        INSERT INTO commerce_finance_audit
            (actor_user_id,entity_type,entity_id,action)
        VALUES (95001,'SALE',95001,'CONFIRMED')
    """)
    require_equal(query("SELECT COUNT(*) FROM commerce_finance_audit"),
                  "1","audit row exists")
    print("PASS: finance ledger constraints, idempotent keys, royalty reversal, monthly uniqueness")

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
        print(f"Commerce financial smoke failed: {error}",file=sys.stderr)
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
