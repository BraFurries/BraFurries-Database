#!/usr/bin/env python3
"""Offline conversion of a private HeidiSQL CSV metadata export to fingerprint JSON.

This script NEVER connects to a database. The input must come from the single
read-only query under validation/sql/physical_schema_readonly_capture.sql.
Keep both files off Git, cloud CI and public issue discussions.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import sys

from physical_schema_fingerprint import (
    FORMAT, SECTIONS, FingerprintError, fingerprint, normalize,
)
from smoke_test import REPOSITORY_ROOT

EXPECTED_TABLES = 107
EXPECTED_COLUMNS = 946
EXPECTED_FK_CONSTRAINTS = 127
EXPECTED_CHECKS = 52


def _delimiter(header: str) -> str:
    # HeidiSQL supports comma, semicolon and tab-delimited CSV; choose using
    # the unambiguous header instead of sniffing the JSON values as CSV.
    header = header.lstrip("\ufeff").strip().lstrip('"').rstrip('"')
    for delim in ("\t", ";", ","):
        if header.replace('"', "") == f"section{delim}metadata":
            return delim
    raise FingerprintError(
        "expected CSV headers: section,metadata (or semicolon/tab delimiter)"
    )


def load_csv(path: Path, *, verify_baseline: bool = True) -> dict:
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        header = stream.readline()
        if not header:
            raise FingerprintError("empty metadata export")
        delimiter = _delimiter(header)
        stream.seek(0)
        reader = csv.DictReader(stream, delimiter=delimiter)
        if reader.fieldnames != ["section", "metadata"]:
            raise FingerprintError("unexpected CSV field headers")

        sections: dict[str, list[dict]] = {kind: [] for kind in SECTIONS}
        environment = None
        for number, row in enumerate(reader, start=2):
            if set(row) != {"section", "metadata"}:
                raise FingerprintError(f"CSV line {number}: unexpected columns")
            section = (row["section"] or "").strip()
            if section not in sections and section != "environment":
                raise FingerprintError(f"CSV line {number}: unknown metadata section")
            try:
                payload = json.loads(row["metadata"] or "")
            except (TypeError, json.JSONDecodeError) as exc:
                raise FingerprintError(f"CSV line {number}: invalid JSON value") from exc
            if not isinstance(payload, dict):
                raise FingerprintError(f"CSV line {number}: expected JSON object")
            if section == "environment":
                if environment is not None:
                    raise FingerprintError("duplicate MariaDB environment record")
                environment = payload
            else:
                sections[section].append(payload)

    if environment is None:
        raise FingerprintError("missing MariaDB environment record")
    result = {"format": FORMAT, "sections": sections, "environment": environment}
    normalize(result)

    if verify_baseline:
        counts = {kind: len(rows) for kind, rows in sections.items()}
        fks = {
            (row["table"], row["constraint"])
            for row in sections["foreign_keys"]
        }
        expected = {
            "tables": EXPECTED_TABLES,
            "columns": EXPECTED_COLUMNS,
            "checks": EXPECTED_CHECKS,
        }
        wrong = {kind: (counts[kind], value)
                 for kind, value in expected.items() if counts[kind] != value}
        if len(fks) != EXPECTED_FK_CONSTRAINTS:
            wrong["FK_constraints"] = (len(fks), EXPECTED_FK_CONSTRAINTS)
        if not counts["indexes"] or not counts["foreign_keys"]:
            wrong["indexes_or_fk_rows"] = "missing"
        if wrong:
            raise FingerprintError(f"incomplete or wrong schema for baseline: {wrong}")
        if not str(environment.get("mariadb_version", "")).startswith("10.6."):
            raise FingerprintError("MariaDB version is not in the tested 10.6 family")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_export", type=Path)
    parser.add_argument("output_json", type=Path)
    args = parser.parse_args()
    export, output = args.csv_export.resolve(), args.output_json.resolve()
    if output.is_relative_to(REPOSITORY_ROOT.resolve()) or export == output:
        print("Refusing to write private production metadata inside repository")
        return 2
    if output.exists():
        print("Refusing to overwrite existing fingerprint")
        return 2
    try:
        snapshot = load_csv(export)
        output.write_text(
            json.dumps(snapshot, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
            encoding="utf-8",
        )
    except (OSError, UnicodeError, FingerprintError, ValueError) as exc:
        print(f"Metadata import failed: {exc}", file=sys.stderr)
        return 2
    print(
        "Baseline metadata: "
        f"{len(snapshot['sections']['tables'])} tables, "
        f"{len(snapshot['sections']['columns'])} columns, "
        f"{len(snapshot['sections']['checks'])} CHECKs"
    )
    print(f"Physical metadata SHA256: {fingerprint(snapshot)}")
    print("Private fingerprint JSON created; compare offline with expected reference.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
