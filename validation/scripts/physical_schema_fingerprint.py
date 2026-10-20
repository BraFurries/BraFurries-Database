#!/usr/bin/env python3
"""Deterministic, read-only MariaDB 10.6 information_schema fingerprint.

An offline comparator accepts two JSON snapshots. The capture adapter below is
ONLY for the fixed disposable MariaDB Compose service, not production.
Snapshots contain schema metadata, never data rows, credentials or schema name.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

FORMAT = "brafurries-mariadb-physical-schema-v1"
SECTIONS = ("tables", "columns", "indexes", "foreign_keys", "checks")
KEYS = {
    "tables": ("table",),
    "columns": ("table", "column"),
    "indexes": ("table", "index", "sequence"),
    "foreign_keys": ("table", "constraint", "position"),
    "checks": ("table", "constraint"),
}

# Each query is SELECT-only and explicitly scoped to the selected schema.
# No application table is queried: all reads are information_schema metadata.
QUERIES = {
    "tables": """
        SELECT JSON_OBJECT(
          'table',TABLE_NAME,'engine',ENGINE,
          'table_collation',TABLE_COLLATION,'row_format',ROW_FORMAT
        ) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE'
          AND TABLE_NAME<>'flyway_schema_history'
        ORDER BY TABLE_NAME
    """,
    "columns": """
        SELECT JSON_OBJECT(
          'table',TABLE_NAME,'column',COLUMN_NAME,'position',ORDINAL_POSITION,
          'type',COLUMN_TYPE,'nullable',IS_NULLABLE,'default',COLUMN_DEFAULT,
          'extra',EXTRA,'expression',GENERATION_EXPRESSION,
          'charset',CHARACTER_SET_NAME,'collation',COLLATION_NAME
        ) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'flyway_schema_history'
        ORDER BY TABLE_NAME, ORDINAL_POSITION
    """,
    "indexes": """
        SELECT JSON_OBJECT(
          'table',TABLE_NAME,'index',INDEX_NAME,'sequence',SEQ_IN_INDEX,
          'column',COLUMN_NAME,'non_unique',NON_UNIQUE,'sub_part',SUB_PART,
          'index_type',INDEX_TYPE,'collation',COLLATION
        ) FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'flyway_schema_history'
        ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX
    """,
    "foreign_keys": """
        SELECT JSON_OBJECT(
          'table',k.TABLE_NAME,'constraint',k.CONSTRAINT_NAME,
          'position',k.ORDINAL_POSITION,'column',k.COLUMN_NAME,
          'referenced_table',k.REFERENCED_TABLE_NAME,
          'referenced_column',k.REFERENCED_COLUMN_NAME,
          'on_delete',r.DELETE_RULE,'on_update',r.UPDATE_RULE
        ) FROM information_schema.KEY_COLUMN_USAGE k
        JOIN information_schema.REFERENTIAL_CONSTRAINTS r
          ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA
         AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME
         AND r.TABLE_NAME=k.TABLE_NAME
        WHERE k.TABLE_SCHEMA=DATABASE()
          AND k.TABLE_NAME<>'flyway_schema_history'
          AND k.REFERENCED_TABLE_NAME IS NOT NULL
        ORDER BY k.TABLE_NAME,k.CONSTRAINT_NAME,k.ORDINAL_POSITION
    """,
    "checks": """
        SELECT JSON_OBJECT(
          'table',TABLE_NAME,'constraint',CONSTRAINT_NAME,'expression',CHECK_CLAUSE
        ) FROM information_schema.CHECK_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA=DATABASE()
          AND TABLE_NAME<>'flyway_schema_history'
        ORDER BY TABLE_NAME,CONSTRAINT_NAME
    """,
}

# Separate environment observation; the database default collation may differ
# while the 107 tables themselves use explicit collations. Not part of hash.
ENVIRONMENT_QUERY = """
 SELECT JSON_OBJECT('mariadb_version',VERSION(),
   'schema_collation',(
     SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA
     WHERE SCHEMA_NAME=DATABASE()
   ),
   'server_collation',@@collation_server)
"""


class FingerprintError(ValueError):
    pass


def _canonical(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def normalize(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or raw.get("format") != FORMAT:
        raise FingerprintError("invalid fingerprint format")
    sections = raw.get("sections")
    if not isinstance(sections, dict) or set(sections) != set(SECTIONS):
        raise FingerprintError("incomplete physical metadata sections")
    out = {}
    for kind in SECTIONS:
        records = sections[kind]
        if not isinstance(records, list) or not all(isinstance(x, dict) for x in records):
            raise FingerprintError(f"invalid metadata rows for {kind}")
        keys = KEYS[kind]
        seen = set()
        for rec in records:
            if any(k not in rec or rec[k] is None for k in keys):
                raise FingerprintError(f"{kind}: missing identity field")
            ident = tuple(str(rec[k]) for k in keys)
            if ident in seen:
                raise FingerprintError(f"{kind}: duplicate object identity {ident}")
            seen.add(ident)
        out[kind] = sorted(records, key=lambda record: _canonical(record))
    if len(out["tables"]) == 0 or len(out["columns"]) == 0:
        raise FingerprintError("empty or inaccessible schema metadata")
    return {"format": FORMAT, "sections": out}


def fingerprint(raw: dict[str, Any]) -> str:
    return hashlib.sha256(_canonical(normalize(raw)).encode("utf-8")).hexdigest()


def diffs(first: dict[str, Any], second: dict[str, Any]) -> list[str]:
    left, right = normalize(first)["sections"], normalize(second)["sections"]
    findings = []
    for kind in SECTIONS:
        key_fields = KEYS[kind]
        def as_map(items):
            return {tuple(str(rec[k]) for k in key_fields): rec for rec in items}
        a, b = as_map(left[kind]), as_map(right[kind])
        for key in sorted(a.keys() | b.keys()):
            label = "/".join(key)
            if key not in a:
                findings.append(f"{kind}: unexpected {label}")
            elif key not in b:
                findings.append(f"{kind}: missing {label}")
            elif a[key] != b[key]:
                changed = sorted(k for k in a[key].keys() | b[key].keys() if a[key].get(k) != b[key].get(k))
                findings.append(f"{kind}: changed {label} fields={','.join(changed)}")
    return findings


def compare_files(expected: Path, observed: Path) -> int:
    try:
        left = json.loads(expected.read_text(encoding="utf-8"))
        right = json.loads(observed.read_text(encoding="utf-8"))
        changes = diffs(left, right)
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        print(f"Fingerprint comparison rejected invalid inputs: {exc}")
        return 2
    print(f"Expected schema fingerprint SHA256: {fingerprint(left)}")
    print(f"Observed schema fingerprint SHA256: {fingerprint(right)}")
    print(f"Structural differences: {len(changes)}")
    for row in changes[:60]:
        print(f"  {row}")
    if len(changes) > 60:
        print(f"  ... and {len(changes) - 60} more")
    return 1 if changes else 0


def _disposable_rows(sql: str) -> list[dict[str, Any]]:
    # Safety is enforced by smoke_test.safety_preflight before this function.
    from smoke_test import (
        COMPOSE_COMMAND, DATABASE_NAME, DATABASE_PASSWORD, DATABASE_USER,
        run_command,
    )
    cmd = run_command(
        [*COMPOSE_COMMAND, "exec", "--no-TTY", "mariadb", "mariadb",
        "--host=127.0.0.1", f"--user={DATABASE_USER}",
        f"--password={DATABASE_PASSWORD}", f"--database={DATABASE_NAME}",
        "--batch", "--raw", "--skip-column-names", "--execute=" + sql],
        show_output=False,
    )
    records = []
    for row in cmd.stdout.splitlines():
        try:
            parsed = json.loads(row)
        except ValueError as exc:
            raise FingerprintError("unexpected MariaDB JSON metadata output") from exc
        if not isinstance(parsed, dict):
            raise FingerprintError("metadata query must return JSON objects")
        records.append(parsed)
    return records


def capture_disposable() -> dict[str, Any]:
    sections = {section: _disposable_rows(QUERIES[section]) for section in SECTIONS}
    context = _disposable_rows(ENVIRONMENT_QUERY)
    if len(context) != 1:
        raise FingerprintError("missing MariaDB environment metadata")
    snapshot = {"format": FORMAT, "sections": sections, "environment": context[0]}
    normalize(snapshot)
    return snapshot


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="mode", required=True)
    comparator = commands.add_parser("compare", help="offline comparison of two JSON captures")
    comparator.add_argument("expected", type=Path)
    comparator.add_argument("observed", type=Path)
    args = parser.parse_args()
    if args.mode == "compare":
        return compare_files(args.expected, args.observed)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
