#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path, PurePosixPath


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
OFFICIAL_ROOTS = {
    "baseline": PurePosixPath("flyway/sql/baseline"),
    "versioned": PurePosixPath("flyway/sql/versioned"),
    "repeatable": PurePosixPath("flyway/sql/repeatable"),
}
SMOKE_ROOT = PurePosixPath("validation/fixtures/flyway-smoke")

VERSIONED_PATTERN = re.compile(
    r"^V(?P<date>\d{8})_(?P<sequence>\d{3})__(?P<description>[a-z][a-z0-9_]*)\.sql$"
)
BASELINE_PATTERN = re.compile(
    r"^B(?P<date>\d{8})_(?P<sequence>\d{3})__(?P<description>[a-z][a-z0-9_]*)\.sql$"
)
REPEATABLE_PATTERN = re.compile(r"^R__(?P<description>[a-z][a-z0-9_]*)\.sql$")
SMOKE_PATTERN = re.compile(
    r"^V00000000_(?P<sequence>\d{3})__(?P<description>[a-z][a-z0-9_]*flyway_smoke[a-z0-9_]*)\.sql$"
)

RESERVED_LOCAL_DRAFT_VERSIONS = {
    "20260824.001",
    "20260824.002",
    "20260824.003",
    "20260824.004",
}


def _is_within(path: PurePosixPath, root: PurePosixPath) -> bool:
    return path == root or root in path.parents


def _tracked_sql_files() -> set[PurePosixPath]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.sql"],
        cwd=REPOSITORY_ROOT,
        check=True,
        capture_output=True,
    )
    return {
        PurePosixPath(item.decode("utf-8"))
        for item in result.stdout.split(b"\0")
        if item
    }


def _working_sql_files_in_allowed_roots() -> set[PurePosixPath]:
    paths: set[PurePosixPath] = set()
    roots = [*OFFICIAL_ROOTS.values(), SMOKE_ROOT]
    for root in roots:
        absolute_root = REPOSITORY_ROOT / Path(*root.parts)
        if not absolute_root.exists():
            continue
        for file_path in absolute_root.rglob("*.sql"):
            paths.add(PurePosixPath(file_path.relative_to(REPOSITORY_ROOT).as_posix()))
    return paths


def _validate_version_date(date_text: str, path: PurePosixPath, errors: list[str]) -> None:
    try:
        datetime.strptime(date_text, "%Y%m%d")
    except ValueError:
        errors.append(f"{path}: version date {date_text!r} is not a real calendar date")


def _version_key(match: re.Match[str]) -> str:
    return f"{match.group('date')}.{match.group('sequence')}"


def validate(allow_official: bool) -> list[str]:
    errors: list[str] = []
    try:
        tracked = _tracked_sql_files()
    except (OSError, subprocess.CalledProcessError) as exc:
        return [f"unable to enumerate tracked SQL files: {exc}"]

    candidates = tracked | _working_sql_files_in_allowed_roots()
    allowed_roots = [*OFFICIAL_ROOTS.values(), SMOKE_ROOT]
    for path in sorted(tracked):
        if not any(_is_within(path, root) for root in allowed_roots):
            errors.append(f"{path}: tracked SQL exists outside an allowed migration/fixture path")

    versions: dict[str, PurePosixPath] = {}
    repeatable_descriptions: dict[str, PurePosixPath] = {}
    smoke_files: list[PurePosixPath] = []

    for path in sorted(candidates):
        parent = path.parent
        name = path.name

        if _is_within(path, SMOKE_ROOT):
            if parent != SMOKE_ROOT:
                errors.append(f"{path}: smoke SQL must be directly inside {SMOKE_ROOT}")
                continue
            match = SMOKE_PATTERN.fullmatch(name)
            if not match:
                errors.append(
                    f"{path}: smoke fixture must use V00000000_NNN__*flyway_smoke*.sql"
                )
                continue
            if match.group("sequence") == "000":
                errors.append(f"{path}: smoke sequence must be between 001 and 999")
            smoke_files.append(path)
            continue

        official_type = next(
            (
                migration_type
                for migration_type, root in OFFICIAL_ROOTS.items()
                if _is_within(path, root)
            ),
            None,
        )
        if official_type is None:
            continue

        expected_parent = OFFICIAL_ROOTS[official_type]
        if parent != expected_parent:
            errors.append(f"{path}: official migrations cannot be nested in subdirectories")
            continue

        if not allow_official:
            errors.append(
                f"{path}: Phase 2 forbids official SQL; only the isolated smoke fixture is allowed"
            )
            continue

        if official_type == "versioned":
            match = VERSIONED_PATTERN.fullmatch(name)
        elif official_type == "baseline":
            match = BASELINE_PATTERN.fullmatch(name)
        else:
            match = REPEATABLE_PATTERN.fullmatch(name)

        if not match:
            errors.append(f"{path}: invalid {official_type} migration name")
            continue

        if official_type == "repeatable":
            description = match.group("description")
            previous = repeatable_descriptions.get(description)
            if previous:
                errors.append(f"{path}: repeatable description duplicates {previous}")
            repeatable_descriptions[description] = path
            continue

        if match.group("sequence") == "000":
            errors.append(f"{path}: sequence must be between 001 and 999")
        _validate_version_date(match.group("date"), path, errors)
        version = _version_key(match)
        if version in RESERVED_LOCAL_DRAFT_VERSIONS:
            errors.append(
                f"{path}: version {version} is reserved by a LOCAL_DRAFT / NOT_REMOTE file"
            )
        previous = versions.get(version)
        if previous:
            errors.append(f"{path}: version {version} duplicates {previous}")
        versions[version] = path

    expected_smoke = PurePosixPath(
        "validation/fixtures/flyway-smoke/"
        "V00000000_001__create_brf_flyway_smoke_test.sql"
    )
    if expected_smoke not in smoke_files:
        errors.append(f"missing required isolated smoke fixture: {expected_smoke}")
    if len(smoke_files) != 1:
        errors.append(
            f"Phase 2 expects exactly one smoke SQL fixture, found {len(smoke_files)}"
        )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate migration paths, naming, and version uniqueness."
    )
    parser.add_argument(
        "--allow-official",
        action="store_true",
        help="Enable future official migration validation. Forbidden in Phase 2 CI.",
    )
    args = parser.parse_args()

    errors = validate(args.allow_official)
    if errors:
        print("Migration validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    mode = "future naming mode" if args.allow_official else "Phase 2 no-official-SQL mode"
    print(f"Migration layout valid ({mode}); isolated smoke fixture is present.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
