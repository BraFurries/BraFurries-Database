#!/usr/bin/env python3
"""Read-only comparison of a structure-only SQL export and ownership/tables.yaml.

Never connects to a database, executes SQL, or prints dump contents/data.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from yaml_utils import load_yaml_unique


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "ownership" / "tables.yaml"
CREATE_TABLE = re.compile(
    r"^\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"
    r"(?:`([a-z][a-z0-9_]*)`|([a-z][a-z0-9_]*))\s*\(",
    re.IGNORECASE | re.MULTILINE,
)


def extract_names(sql: str) -> list[str]:
    # This deliberately recognizes only ordinary CREATE TABLE definitions.
    # It is not a complete SQL parser or a column/index fingerprint.
    return [(m.group(1) or m.group(2)).lower() for m in CREATE_TABLE.finditer(sql)]


def reconcile(sql_path: Path, manifest_path: Path = MANIFEST) -> int:
    try:
        sql = sql_path.read_text(encoding="utf-8-sig")
        doc = load_yaml_unique(manifest_path)
        expected = [entry["table"] for entry in doc["tables"]]
    except (OSError, UnicodeError, TypeError, KeyError, ValueError) as exc:
        print(f"Inventory comparison failed to read inputs: {exc}", file=sys.stderr)
        return 2

    actual = extract_names(sql)
    if not actual:
        print("No CREATE TABLE definitions detected; check export scope.", file=sys.stderr)
        return 2

    repeated = sorted({name for name in actual if actual.count(name) > 1})
    catalog_repeated = sorted({name for name in expected if expected.count(name) > 1})
    actual_set = set(actual)
    expected_set = set(expected)

    print(f"Dump tables: {len(actual)} ({len(actual_set)} unique)")
    print(f"Catalog entries: {len(expected)} ({len(expected_set)} unique)")
    print(f"Export-only tables: {len(actual_set - expected_set)}")
    for name in sorted(actual_set - expected_set):
        print(f"  + {name}")
    print(f"Catalog-only tables: {len(expected_set - actual_set)}")
    for name in sorted(expected_set - actual_set):
        print(f"  - {name}")

    if repeated or catalog_repeated:
        print(f"Duplicate CREATE TABLE names: {repeated}", file=sys.stderr)
        print(f"Duplicate catalog names: {catalog_repeated}", file=sys.stderr)
        return 1

    count = doc.get("table_count_expected")
    if count != len(expected):
        print(
            f"Manifest expected count {count} does not match {len(expected)} entries",
            file=sys.stderr,
        )
        return 1

    if actual_set != expected_set:
        return 1
    print("All exported table names match the ownership manifest.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema_sql", type=Path, help="local SQL structure export (never uploaded)")
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    args = parser.parse_args()
    return reconcile(args.schema_sql, args.manifest)


if __name__ == "__main__":
    raise SystemExit(main())
