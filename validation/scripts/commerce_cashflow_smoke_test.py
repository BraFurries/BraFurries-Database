#!/usr/bin/env python3
"""Validate cashflow and sale fees with disposable MariaDB/Flyway only."""
from __future__ import annotations
import sys
from smoke_test import (
    SmokeFailure, assert_no_resources_remain, compose, down,
    expect_sql_failure, query, require_equal, safety_preflight, start_empty_database
)

def verify() -> None:
    require_equal(query(
        "SELECT COUNT(*) FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='commerce_cash_movements'"),
        "1", "cash movements created")
    require_equal(query("SELECT COUNT(*) FROM commerce_cash_movements"), "0",
                  "no automatic funding/payment entries inserted")
    require_equal(query(
        "SELECT COUNT(*) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='commerce_cash_movements' "
        "AND COLUMN_NAME='community_id'"), "0", "outside all Community tenants")
    for table in ["commerce_user_permissions","commerce_role_permissions"]:
        require_equal(query(
            "SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS "
            "WHERE CONSTRAINT_SCHEMA=DATABASE() AND CONSTRAINT_NAME="
            f"'{('ck_cup_permission' if table=='commerce_user_permissions' else 'ck_crp_permission')}' "
            "AND CHECK_CLAUSE LIKE '%CASHFLOW_MANAGE%'"),
            "1", f"{table} authorizes only known codes including CASHFLOW_MANAGE")

    query("""
        INSERT INTO users (id,display_name)
        VALUES (97001,'Commercial owner'),(97002,'Contributor')
    """)
    query("""
        INSERT INTO commerce_sales
          (id,request_key,request_sha256,channel,sold_on,
           gross_amount,created_by_user_id,payment_method,
           processing_provider,processing_fee_percent,processing_fee_fixed,
           processing_fee_amount)
        VALUES (97001,'11111111-1111-4111-8111-222222222222',
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'EVENT','2026-11-03',100.00,97001,'CARD_CREDIT','Maquininha',3.5000,1.00,4.50)
    """)
    require_equal(query(
        "SELECT net_receipt_amount FROM commerce_sales WHERE id=97001"),
        "95.50", "fees reduce receipt, preserving R$100 gross")
    expect_sql_failure("""
        INSERT INTO commerce_sales
          (request_key,request_sha256,channel,sold_on,
           gross_amount,created_by_user_id,payment_method,
           processing_fee_percent,processing_fee_fixed,processing_fee_amount)
        VALUES ('22222222-2222-4222-8222-333333333333',
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'EVENT','2026-11-03',100.00,97001,'CARD_DEBIT',3.50,1.00,5.00)
    """, "fee snapshot must match 3.5% plus R$1 rounded")
    expect_sql_failure("""
        UPDATE commerce_sales SET processing_fee_amount=101 WHERE id=97001
    """, "cannot charge more fees than gross")
    query("""
        INSERT INTO commerce_cash_movements
          (id,request_key,request_sha256,movement_type,amount,occurred_on,
           category,description,counterparty_label,counterparty_user_id,
           contributor_type,contribution_nature,payment_method,
           created_by_user_id)
        VALUES (97001,'33333333-3333-4333-8333-444444444444',
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          'CONTRIBUTION',300.00,'2026-11-03','APORTE','Aporte para materiais',
          'Membro da comunidade',97002,'COMMUNITY_MEMBER','REPAYABLE','PIX',97001)
    """)
    require_equal(query(
        "SELECT signed_amount FROM commerce_cash_movements WHERE id=97001"),
        "300.00", "funding adds cash without counting operating income")
    query("""
        INSERT INTO commerce_cash_movements
          (id,request_key,request_sha256,movement_type,amount,occurred_on,
           category,description,counterparty_label,payment_method,created_by_user_id)
        VALUES (97002,'44444444-4444-4444-8444-555555555555',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          'EXPENSE',80.00,'2026-11-03','MATERIAIS','Compra do material',
          'Fornecedor', 'PIX',97001)
    """)
    require_equal(query(
        "SELECT signed_amount FROM commerce_cash_movements WHERE id=97002"),
        "-80.00", "operating expense subtracts cash")
    expect_sql_failure("""
        INSERT INTO commerce_cash_movements
          (request_key,request_sha256,movement_type,amount,occurred_on,
           category,description,counterparty_label,payment_method,created_by_user_id)
        VALUES ('55555555-5555-4555-8555-666666666666',
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          'CONTRIBUTION',40.00,'2026-11-03','APORTE','Aporte inválido',
          'Outra pessoa', 'PIX',97001)
    """, "funding must record source and repayable/nonrepayable nature")
    expect_sql_failure("""
        INSERT INTO commerce_cash_movements
          (request_key,request_sha256,movement_type,amount,occurred_on,
           category,description,counterparty_label,
           contributor_type,contribution_nature,payment_method,created_by_user_id)
        VALUES ('66666666-6666-4666-8666-777777777777',
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          'EXPENSE',40.00,'2026-11-03','CUSTO','Despesa inválida',
          'Fornecedor','OWNER','REPAYABLE','PIX',97001)
    """, "operating expenses cannot masquerade as financing")
    query("""
        INSERT INTO commerce_cash_movements
          (id,request_key,request_sha256,movement_type,event_kind,reversal_of_id,
           amount,occurred_on,category,description,counterparty_label,
           counterparty_user_id,contributor_type,contribution_nature,
           payment_method,reversal_reason,created_by_user_id)
        VALUES (97003,'77777777-7777-4777-8777-888888888888',
          '9999999999999999999999999999999999999999999999999999999999999999',
          'CONTRIBUTION','REVERSAL',97001,300.00,'2026-11-03','APORTE',
          'Aporte para materiais','Membro da comunidade',97002,
          'COMMUNITY_MEMBER','REPAYABLE','PIX','Registro duplicado',97001)
    """)
    require_equal(query(
        "SELECT SUM(signed_amount) FROM commerce_cash_movements "
        "WHERE movement_type='CONTRIBUTION'"), "0.00",
        "reversal offsets funding without deleting history")
    expect_sql_failure("""
        INSERT INTO commerce_cash_movements
          (request_key,request_sha256,movement_type,event_kind,reversal_of_id,
           amount,occurred_on,category,description,counterparty_label,
           contributor_type,contribution_nature,payment_method,
           reversal_reason,created_by_user_id)
        VALUES ('88888888-8888-4888-8888-999999999999',
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'CONTRIBUTION','REVERSAL',97001,300.00,'2026-11-03','APORTE',
          'Aporte para materiais','Membro da comunidade',
          'COMMUNITY_MEMBER','REPAYABLE','PIX','Duplicado',97001)
    """, "only one compensating reversal per original")
    require_equal(query("SELECT COUNT(*) FROM commerce_cash_movements"),"3",
                  "only legitimate movements and reversal persisted")
    print("PASS: sale card fees, funding classification, ledger signs, idempotent reversals")

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
        print(f"Commerce cashflow smoke failed: {error}",file=sys.stderr)
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
