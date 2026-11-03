#!/usr/bin/env python3
"""Smoke-test private BraFurries commercial catalog on isolated MariaDB/Flyway."""
from __future__ import annotations
import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight, start_empty_database
)

def validate_catalog() -> None:
    tables = [
        "commerce_contract_templates", "commerce_artworks", "commerce_artwork_contracts",
        "commerce_suppliers", "commerce_products", "commerce_product_artworks",
        "commerce_production_batches", "commerce_catalog_audit"
    ]
    for table in tables:
        require_equal(query(f"SELECT COUNT(*) FROM information_schema.TABLES "
                            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}'"),
                      "1", f"{table} exists")
        require_equal(query(f"SELECT COUNT(*) FROM {table}"), "0", f"{table} begins empty")
        require_equal(query(f"SELECT COUNT(*) FROM information_schema.COLUMNS "
                            f"WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='{table}' "
                            "AND COLUMN_NAME='community_id'"),
                      "0", f"{table} does not expose Community tenant")
    query("INSERT INTO users (id, display_name) VALUES "
          "(92001,'Director'),(92002,'Artist'),(92003,'Other artist')")
    query("""
       INSERT INTO commerce_contract_templates
          (id,name,modality,royalty_method,royalty_percent,created_by_user_id)
       VALUES (92001,'Royalties model','ROYALTY','PERCENT_GROSS',12.5000,92001)
    """)
    expect_sql_failure("""
       INSERT INTO commerce_contract_templates
          (name,modality,royalty_method,royalty_percent,created_by_user_id)
       VALUES ('Invalid percentage','ROYALTY','PERCENT_GROSS',101,92001)
    """, "percentage over 100 is rejected")
    expect_sql_failure("""
       INSERT INTO commerce_contract_templates
          (name,modality,royalty_method,created_by_user_id)
       VALUES ('Missing percentage','ROYALTY','PERCENT_GROSS',92001)
    """, "royalty percentage cannot be missing")
    query("""
       INSERT INTO commerce_artworks
          (id,title,artist_user_id,creation_cost,status,created_by_user_id)
       VALUES (92001,'Art illustration',92002,350.00,'ACTIVE',92001)
    """)
    expect_sql_failure("""
       INSERT INTO commerce_artworks
          (title,artist_user_id,creation_cost,created_by_user_id)
       VALUES ('Negative creation cost',92002,-10.00,92001)
    """, "negative creation cost is rejected")
    query("""
       INSERT INTO commerce_artwork_contracts
          (id,artwork_id,template_id,artist_user_id,modality_snapshot,
           royalty_method_snapshot,royalty_percent_snapshot,effective_from,
           signed_storage_key,signed_sha256,signed_bytes,created_by_user_id)
       VALUES
          (92001,92001,92001,92002,'ROYALTY','PERCENT_GROSS',12.5000,
           '2026-11-03','commerce/contracts/document-1.pdf',
           'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
           1000,92001)
    """)
    expect_sql_failure("""
       INSERT INTO commerce_artwork_contracts
          (artwork_id,template_id,artist_user_id,modality_snapshot,
           royalty_method_snapshot,royalty_percent_snapshot,effective_from,
           signed_storage_key,signed_sha256,signed_bytes,created_by_user_id)
       VALUES
          (92001,92001,92003,'ROYALTY','PERCENT_GROSS',12.5000,
           '2026-11-03','commerce/contracts/other-artist.pdf',
           'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
           1000,92001)
    """, "agreement artist must equal artwork artist")
    expect_sql_failure("""
       INSERT INTO commerce_artwork_contracts
          (artwork_id,template_id,artist_user_id,modality_snapshot,
           royalty_method_snapshot,royalty_percent_snapshot,effective_from,
           signed_storage_key,signed_sha256,signed_bytes,created_by_user_id)
       VALUES
          (92001,92001,92002,'ROYALTY','PERCENT_GROSS',12.5000,
           '2026-11-03','commerce/contracts/document-2.pdf',
           'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
           1000,92001)
    """, "only one active signed contract per artwork")
    query("""
       UPDATE commerce_artwork_contracts
          SET status='TERMINATED',ended_at=CURRENT_TIMESTAMP(6) WHERE id=92001
    """)
    query("""
       INSERT INTO commerce_artwork_contracts
          (artwork_id,template_id,artist_user_id,modality_snapshot,
           royalty_method_snapshot,royalty_percent_snapshot,effective_from,
           signed_storage_key,signed_sha256,signed_bytes,created_by_user_id)
       VALUES
          (92001,92001,92002,'ROYALTY','PERCENT_GROSS',12.5000,
           '2026-11-03','commerce/contracts/document-2.pdf',
           'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
           1000,92001)
    """)
    query("""
       INSERT INTO commerce_suppliers (id,name,created_by_user_id)
       VALUES (92001,'Supplier fixture',92001)
    """)
    query("""
       INSERT INTO commerce_products
          (id,sku,name,estimated_unit_cost,suggested_price,created_by_user_id)
       VALUES (92001,'SKU-92001','Printed mug',24.50,64.90,92001)
    """)
    query("""
       INSERT INTO commerce_product_artworks
          (product_id,artwork_id,royalty_allocation_percent,created_by_user_id)
       VALUES (92001,92001,100.0000,92001)
    """)
    expect_sql_failure("""
       INSERT INTO commerce_product_artworks
          (product_id,artwork_id,royalty_allocation_percent,created_by_user_id)
       VALUES (92001,92001,50.0000,92001)
    """, "duplicate artwork-product assignment is rejected")
    expect_sql_failure("""
       INSERT INTO commerce_product_artworks
          (product_id,artwork_id,royalty_allocation_percent,created_by_user_id)
       VALUES (92001,999999,50.0000,92001)
    """, "unknown artwork cannot be assigned")
    query("""
       INSERT INTO commerce_production_batches
          (product_id,supplier_id,quantity,unit_cost,additional_cost,total_cost,
           produced_on,created_by_user_id)
       VALUES (92001,92001,10,24.50,5.00,250.00,'2026-11-03',92001)
    """)
    expect_sql_failure("""
       INSERT INTO commerce_production_batches
          (product_id,supplier_id,quantity,unit_cost,additional_cost,total_cost,
           produced_on,created_by_user_id)
       VALUES (92001,92001,10,24.50,5.00,100.00,'2026-11-03',92001)
    """, "batch total cost must equal unit cost times quantity plus extras")
    require_equal(query("SELECT COUNT(*) FROM commerce_production_batches"),
                  "1", "valid production lot persisted")
    query("""
       INSERT INTO commerce_catalog_audit (actor_user_id, entity_type, entity_id, action)
       VALUES (92001,'PRODUCT',92001,'CREATED')
    """)
    require_equal(query("SELECT COUNT(*) FROM commerce_catalog_audit"),
                  "1", "catalog audit persisted")
    print("PASS: commerce catalog FKs, constraints, active agreement uniqueness, cost precision")

def main() -> int:
    preflight = False
    status = 0
    try:
        safety_preflight()
        preflight = True
        down()
        start_empty_database()
        compose("run","--rm","flyway","migrate")
        validate_catalog()
        compose("run","--rm","flyway","validate")
    except SmokeFailure as ex:
        print(f"Commerce catalog smoke failed: {ex}",file=sys.stderr)
        status=1
    finally:
        if preflight:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as ex:
                print(f"Cleanup failed: {ex}",file=sys.stderr)
                status=1
    return status

if __name__=="__main__":
    raise SystemExit(main())
