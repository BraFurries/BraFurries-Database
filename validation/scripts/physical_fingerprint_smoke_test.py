#!/usr/bin/env python3
"""Verify MariaDB physical-schema fingerprint catches drift (disposable only)."""
from __future__ import annotations

import sys
from pathlib import Path
from tempfile import TemporaryDirectory

from physical_schema_fingerprint import (
    capture_disposable,
    compare_files,
    diffs,
    fingerprint,
    normalize,
)
from smoke_test import (
    SmokeFailure, DATABASE_NAME, DATABASE_PASSWORD, DATABASE_USER,
    assert_no_resources_remain, compose, down, query, require_equal,
    safety_preflight, start_empty_database,
)

BASELINE_LOCATIONS = "-locations=filesystem:/flyway/baseline,filesystem:/flyway/official"
PROBE_COLUMN = "__brf_fingerprint_synthetic_probe"


def alter_on_disposable(sql: str) -> None:
    compose(
        "exec", "--no-TTY", "mariadb", "mariadb",
        "--host=127.0.0.1", f"--user={DATABASE_USER}",
        f"--password={DATABASE_PASSWORD}", f"--database={DATABASE_NAME}",
        "--execute=" + sql,
    )


def run_smoke() -> None:
    down()
    start_empty_database()
    compose("run", "--rm", "--no-deps", "flyway", BASELINE_LOCATIONS, "migrate")

    pristine = capture_disposable()
    structure = normalize(pristine)["sections"]
    require_equal(str(len(structure["tables"])), "107", "physical snapshot contains 107 tables")
    require_equal(str(len(structure["columns"])), "946", "physical snapshot contains 946 columns")
    unique_fk = {(row["table"], row["constraint"]) for row in structure["foreign_keys"]}
    require_equal(str(len(unique_fk)), "127", "physical snapshot includes 127 FK constraints")
    require_equal(str(len(structure["checks"])), "52", "physical snapshot includes 52 CHECK constraints")
    if any(name in str(structure) for name in ("flyway_schema_history", PROBE_COLUMN)):
        raise SmokeFailure("snapshot includes internal Flyway metadata or unexpected probe")

    with TemporaryDirectory(prefix="brf_schema_disposable_") as directory:
        expected = Path(directory) / "expected.json"
        observed = Path(directory) / "observed.json"
        import json
        expected.write_text(json.dumps(pristine, ensure_ascii=False), encoding="utf-8")
        observed.write_text(json.dumps(capture_disposable(), ensure_ascii=False), encoding="utf-8")
        require_equal(str(compare_files(expected, observed)), "0", "repeat capture is deterministic")

        # Simulated drift on a disposable synthetic schema ONLY.
        alter_on_disposable(
            f"ALTER TABLE backup_guild_locks ADD COLUMN {PROBE_COLUMN} INT NULL"
        )
        changed = capture_disposable()
        findings = diffs(pristine, changed)
        if not any("columns:" in item and PROBE_COLUMN in item for item in findings):
            raise SmokeFailure("added physical column did not trigger drift detection")
        if fingerprint(pristine) == fingerprint(changed):
            raise SmokeFailure("drift did not change the schema fingerprint")
        observed.write_text(json.dumps(changed, ensure_ascii=False), encoding="utf-8")
        require_equal(str(compare_files(expected, observed)), "1", "offline compare rejects drift")
        print("PASS: a deliberately added column is detected in the disposable schema")

        alter_on_disposable(
            f"ALTER TABLE backup_guild_locks DROP COLUMN {PROBE_COLUMN}"
        )
        restored = capture_disposable()
        require_equal(str(len(diffs(pristine, restored))), "0", "restored DDL matches baseline")
        observed.write_text(json.dumps(restored, ensure_ascii=False), encoding="utf-8")
        require_equal(str(compare_files(expected, observed)), "0", "restored schema fingerprint matches")
    print("PASS: fingerprint detects drift and recovers after synthetic rollback")


def main() -> int:
    result = 0
    preflight_accepted = False
    try:
        safety_preflight()
        preflight_accepted = True
        run_smoke()
    except (SmokeFailure, ValueError) as error:
        print(f"Physical fingerprint smoke failed: {error}", file=sys.stderr)
        result = 1
    finally:
        if preflight_accepted:
            try:
                down()
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Cleanup failed: {error}", file=sys.stderr)
                result = 1
    return result


if __name__ == "__main__":
    raise SystemExit(main())
