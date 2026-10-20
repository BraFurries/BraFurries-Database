#!/usr/bin/env python3
"""Prove the 107-table baseline on a disposable MariaDB only."""
from __future__ import annotations

import re
import sys
from pathlib import Path

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
from yaml_utils import load_yaml_unique

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "flyway/sql/baseline/B20261020_001__adopt_production_schema.sql"
MANIFEST = ROOT / "ownership/tables.yaml"
VERSION = "20261020.001"
LOCATIONS = "-locations=filesystem:/flyway/baseline,filesystem:/flyway/official"
TABLE_NAME = re.compile(r"(?m)^CREATE TABLE `([a-z][a-z0-9_]*)`\s*\(")


def flyway(command: str, *, check: bool = True) -> int:
    run = compose("run", "--rm", "--no-deps", "flyway", LOCATIONS, command, check=check)
    return run.returncode


def verify_schema() -> None:
    expected = sorted(item["table"] for item in load_yaml_unique(MANIFEST)["tables"])
    actual = sorted(
        query(
            "SELECT TABLE_NAME FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' "
            "AND TABLE_NAME<>'flyway_schema_history' ORDER BY TABLE_NAME"
        ).splitlines()
    )
    if expected != actual:
        missing, extra = sorted(set(expected)-set(actual)), sorted(set(actual)-set(expected))
        raise SmokeFailure(f"schema inventory mismatch: missing={missing}, unexpected={extra}")
    print("PASS: exact 107-table inventory matches current ownership manifest")
    checks = [
        ("946", "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()", "946 columns"),
        ("127", "SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE()", "127 foreign keys"),
        ("105", "SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND CONSTRAINT_TYPE='PRIMARY KEY'", "105 primary keys; two legacy tables have none"),
        ("52", "SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND CONSTRAINT_TYPE='CHECK'", "52 CHECK constraints"),
        ("1", "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='schema_migrations'", "legacy schema history table preserved"),
    ]
    for count, statement, description in checks:
        require_equal(query(statement), count, description)
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA=DATABASE() AND COLUMN_NAME IN ('active_name','active_user_low_id','active_user_high_id') "
            "AND EXTRA LIKE '%GENERATED%'"
        ),
        "3",
        "three generated columns preserved",
    )


def require_history(history_type: str) -> None:
    require_equal(
        query("SELECT COUNT(*) FROM flyway_schema_history WHERE success=1"),
        "1",
        "exactly one Flyway baseline record",
    )
    require_equal(
        query("SELECT CONCAT(version,'|',type) FROM flyway_schema_history WHERE success=1"),
        f"{VERSION}|{history_type}",
        "Flyway baseline version and execution mode",
    )


def verify_sql_static() -> None:
    ddl = BASELINE.read_text(encoding="utf-8")
    names = TABLE_NAME.findall(ddl)
    expected = [item["table"] for item in load_yaml_unique(MANIFEST)["tables"]]
    if len(names)!=107 or len(set(names))!=107 or set(names)!=set(expected):
        raise SmokeFailure("baseline SQL does not contain exactly the 107 cataloged tables")
    if re.search(r"(?im)^\s*(?:CREATE DATABASE|USE |INSERT |UPDATE |DELETE |GRANT |DROP |ALTER USER)\b", ddl):
        raise SmokeFailure("baseline contains forbidden schema selector, data DML or destructive SQL")
    if "AUTO_INCREMENT=" in ddl or "IF NOT EXISTS" in ddl:
        raise SmokeFailure("baseline must be fail-fast and sanitized of source counters")
    created = set()
    for match in re.finditer(r"(?ms)^CREATE TABLE `([a-z][a-z0-9_]*)`\s*\((.*?)^\) ENGINE=", ddl):
        name, definition = match.groups()
        for parent in re.findall(r"\bREFERENCES\s+`?([a-z][a-z0-9_]*)`?\s*\(",definition,re.I):
            if parent != name and parent not in created:
                raise SmokeFailure(f"FK dependency not yet created: {name} -> {parent}")
        created.add(name)
    if len(created) != 107:
        raise SmokeFailure("baseline table boundaries unparseable")
    print("PASS: baseline SQL is sanitized, dependency-ordered and covers 107 names")


def validate_explicit_adoption_simulation() -> None:
    # Never executed against production. This uses only the fixed disposable test schema.
    # Simulates an old existing database after a snapshot import: a full schema
    # without Flyway history, where only explicit 'baseline' is permitted.
    from smoke_test import DATABASE_NAME
    from smoke_test import DATABASE_USER
    from smoke_test import DATABASE_PASSWORD
    compose(
        "exec", "--no-TTY", "mariadb", "mariadb",
        "--host=127.0.0.1", f"--user={DATABASE_USER}",
        f"--password={DATABASE_PASSWORD}",f"--database={DATABASE_NAME}",
        "--execute=DROP TABLE flyway_schema_history;",
    )
    if flyway("migrate",check=False)==0:
        raise SmokeFailure("migrate unexpectedly accepted existing non-empty schema without baseline")
    require_equal(
        query("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()"),
        "107",
        "failed migrate left all 107 tables intact",
    )
    compose(
        "run","--rm","--no-deps","flyway",
        LOCATIONS,
        f"-baselineVersion={VERSION}",
        "-baselineDescription=Explicit adopted schema state",
        "baseline",
    )
    require_history("BASELINE")
    verify_schema()
    flyway("validate")
    flyway("migrate")
    require_history("BASELINE")
    verify_schema()
    print("PASS: explicit adoption adds only Flyway metadata in disposable schema")


def run() -> None:
    verify_sql_static()
    down()
    start_empty_database()
    flyway("migrate")
    require_history("SQL_BASELINE")
    verify_schema()
    flyway("validate")
    flyway("migrate")
    require_history("SQL_BASELINE")
    validate_explicit_adoption_simulation()


def main() -> int:
    result = 0
    try:
        safety_preflight()
        run()
    except SmokeFailure as error:
        print(f"Baseline smoke failed: {error}",file=sys.stderr)
        result=1
    finally:
        down()
        try:
            assert_no_resources_remain()
        except SmokeFailure as error:
            print(f"Cleanup verification failed: {error}",file=sys.stderr)
            result=1
    if result==0:
        print("PASS: canonical baseline and explicit adoption simulation on disposable MariaDB")
    return result


if __name__=="__main__":
    raise SystemExit(main())
