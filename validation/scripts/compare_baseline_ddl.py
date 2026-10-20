#!/usr/bin/env python3
"""Offline structural comparison of a private schema dump to Flyway baseline.

Compares CREATE TABLE definitions except allowed AUTO_INCREMENT counters,
IF NOT EXISTS and table order. Does not execute SQL or print row contents.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "flyway/sql/baseline/B20261020_001__adopt_production_schema.sql"
TABLE = re.compile(
    r"(?ms)^CREATE TABLE(?: IF NOT EXISTS)? [\x60]([a-z][a-z0-9_]*)[\x60] "
    r"\((.*?)^\) ENGINE=([^;]+);"
)
AUTO_INCREMENT_COUNTER = re.compile(r"\sAUTO_INCREMENT=\d+\b")


def structural_statements(sql: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for match in TABLE.finditer(sql):
        name, fields, opts = match.groups()
        if name in parsed:
            raise ValueError(f"duplicate CREATE TABLE: {name}")
        cleaned = AUTO_INCREMENT_COUNTER.sub("", opts).strip()
        quoted_name = chr(96) + name + chr(96)
        parsed[name] = f"CREATE TABLE {quoted_name} ({fields}) ENGINE={cleaned};"
    if not parsed:
        raise ValueError("no supported CREATE TABLE statements in input")
    return parsed


def digest(statements: dict[str, str]) -> str:
    normalized = "\n".join(
        f"{name}\0{statements[name]}" for name in sorted(statements)
    )
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def compare(source: Path, canonical: Path = BASELINE) -> int:
    try:
        from_dump = structural_statements(source.read_text(encoding="utf-8-sig"))
        from_baseline = structural_statements(canonical.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, ValueError) as err:
        print(f"Unable to parse structural input: {err}", file=sys.stderr)
        return 2

    missing = sorted(set(from_dump) - set(from_baseline))
    unexpected = sorted(set(from_baseline) - set(from_dump))
    changed = sorted(name for name in from_dump.keys() & from_baseline.keys()
                     if from_dump[name] != from_baseline[name])
    print(f"Input export: {len(from_dump)} tables | digest: {digest(from_dump)}")
    print(f"Canonical baseline: {len(from_baseline)} tables | digest: {digest(from_baseline)}")
    print(f"Missing from baseline: {len(missing)}: {', '.join(missing) or '-'}")
    print(f"Extra in baseline: {len(unexpected)}: {', '.join(unexpected) or '-'}")
    print(f"Changed full definitions: {len(changed)}: {', '.join(changed) or '-'}")
    if missing or unexpected or changed:
        return 1
    print("MATCH: full exported table DDL (except volatile counters and creation order).")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("private_schema_dump", type=Path)
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    args = parser.parse_args()
    return compare(args.private_schema_dump, args.baseline)


if __name__ == "__main__":
    raise SystemExit(main())
