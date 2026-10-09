#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

from yaml_utils import load_yaml_unique


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TABLES_PATH = REPOSITORY_ROOT / "ownership" / "tables.yaml"
STATUSES_PATH = REPOSITORY_ROOT / "ownership" / "statuses.yaml"
TABLE_NAME_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")

ROOT_REQUIRED_FIELDS = {
    "manifest_version",
    "last_reviewed",
    "table_count_expected",
    "schema_authority",
    "tables",
}

TABLE_REQUIRED_FIELDS = {
    "table",
    "status",
    "domain_owner",
    "schema_authority",
    "runtime_readers",
    "runtime_writers",
    "identity_merge_writer",
    "current_ddl_owner",
    "id_semantics",
    "logical_key",
    "physical_keys",
    "merge_policy",
    "current_consumers",
    "current_ddl_paths",
    "evidence",
    "notes",
}

LIST_FIELDS = {
    "runtime_readers",
    "runtime_writers",
    "identity_merge_writer",
    "id_semantics",
    "current_consumers",
    "current_ddl_paths",
    "evidence",
}


def _registered_keys(document: dict[str, Any], field: str, errors: list[str]) -> set[str]:
    values = document.get(field)
    if not isinstance(values, dict) or not values:
        errors.append(f"ownership/statuses.yaml: {field!r} must be a non-empty mapping")
        return set()
    return set(values)


def _validate_unique_list(
    table_name: str, field: str, value: Any, errors: list[str]
) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{table_name}: {field} must be a list")
        return []
    if not all(isinstance(item, str) and item for item in value):
        errors.append(f"{table_name}: {field} must contain only non-empty strings")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{table_name}: {field} contains duplicate values")
    return value


def validate() -> list[str]:
    errors: list[str] = []
    try:
        manifest = load_yaml_unique(TABLES_PATH)
        registry = load_yaml_unique(STATUSES_PATH)
    except Exception as exc:  # YAML errors should be presented as validation failures.
        return [f"YAML loading failed: {exc}"]

    if not isinstance(manifest, dict):
        return ["ownership/tables.yaml: document root must be a mapping"]
    if not isinstance(registry, dict):
        return ["ownership/statuses.yaml: document root must be a mapping"]

    missing_root = ROOT_REQUIRED_FIELDS - set(manifest)
    if missing_root:
        errors.append(
            "ownership/tables.yaml: missing root fields: "
            + ", ".join(sorted(missing_root))
        )

    schema_authorities = _registered_keys(registry, "schema_authorities", errors)
    systems = _registered_keys(registry, "systems", errors)
    domain_owners = _registered_keys(registry, "domain_owners", errors)
    statuses = _registered_keys(registry, "statuses", errors)
    ddl_owners = _registered_keys(registry, "current_ddl_owners", errors)
    merge_policies = _registered_keys(registry, "merge_policy_values", errors)

    expected_authority = manifest.get("schema_authority")
    if expected_authority not in schema_authorities:
        errors.append(
            "ownership/tables.yaml: schema_authority must be registered in "
            "ownership/statuses.yaml"
        )

    tables = manifest.get("tables")
    if not isinstance(tables, list):
        return errors + ["ownership/tables.yaml: tables must be a list"]

    expected_count = manifest.get("table_count_expected")
    if not isinstance(expected_count, int) or isinstance(expected_count, bool):
        errors.append("ownership/tables.yaml: table_count_expected must be an integer")
    elif expected_count != len(tables):
        errors.append(
            f"ownership/tables.yaml: table_count_expected={expected_count}, "
            f"but {len(tables)} table entries exist"
        )

    seen_names: set[str] = set()
    for index, table in enumerate(tables, start=1):
        label = f"tables[{index}]"
        if not isinstance(table, dict):
            errors.append(f"{label}: entry must be a mapping")
            continue

        missing = TABLE_REQUIRED_FIELDS - set(table)
        if missing:
            errors.append(f"{label}: missing fields: {', '.join(sorted(missing))}")

        name = table.get("table")
        if not isinstance(name, str) or not TABLE_NAME_PATTERN.fullmatch(name):
            errors.append(f"{label}: table must be a lower_snake_case name")
            table_name = label
        else:
            table_name = name
            if name in seen_names:
                errors.append(f"{name}: duplicate table entry")
            seen_names.add(name)

        if table.get("schema_authority") != expected_authority:
            errors.append(
                f"{table_name}: schema_authority must be {expected_authority!r}"
            )
        if table.get("status") not in statuses:
            errors.append(f"{table_name}: unregistered status {table.get('status')!r}")
        if table.get("domain_owner") not in domain_owners:
            errors.append(
                f"{table_name}: unregistered domain_owner {table.get('domain_owner')!r}"
            )
        if table.get("current_ddl_owner") not in ddl_owners:
            errors.append(
                f"{table_name}: unregistered current_ddl_owner "
                f"{table.get('current_ddl_owner')!r}"
            )
        if table.get("merge_policy") not in merge_policies:
            errors.append(
                f"{table_name}: unregistered merge_policy {table.get('merge_policy')!r}"
            )

        validated_lists: dict[str, list[str]] = {}
        for field in LIST_FIELDS:
            if field in table:
                validated_lists[field] = _validate_unique_list(
                    table_name, field, table[field], errors
                )

        for field in (
            "runtime_readers",
            "runtime_writers",
            "identity_merge_writer",
            "current_consumers",
        ):
            for system in validated_lists.get(field, []):
                if system not in systems:
                    errors.append(
                        f"{table_name}: {field} contains unregistered system {system!r}"
                    )

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("Ownership manifest validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    manifest = load_yaml_unique(TABLES_PATH)
    print(
        "Ownership manifest valid: "
        f"{len(manifest['tables'])} unique tables, registered values only, "
        "UNKNOWN/TODO markers allowed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
