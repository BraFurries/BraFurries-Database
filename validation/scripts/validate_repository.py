#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

from yaml_utils import load_yaml_unique


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
MARKDOWN_LINK_PATTERN = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
EXTERNAL_SCHEMES = ("http://", "https://", "mailto:", "tel:")


def _repository_files(suffixes: set[str]) -> list[Path]:
    return sorted(
        path
        for path in REPOSITORY_ROOT.rglob("*")
        if path.is_file()
        and ".git" not in path.parts
        and path.suffix.lower() in suffixes
    )


def _validate_yaml(errors: list[str]) -> int:
    yaml_files = _repository_files({".yaml", ".yml"})
    for path in yaml_files:
        try:
            load_yaml_unique(path)
        except Exception as exc:
            relative = path.relative_to(REPOSITORY_ROOT)
            errors.append(f"{relative}: invalid YAML: {exc}")
    return len(yaml_files)


def _local_link_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(maxsplit=1)[0]
    if not target or target.startswith("#") or target.lower().startswith(EXTERNAL_SCHEMES):
        return None
    return unquote(target.split("#", maxsplit=1)[0].split("?", maxsplit=1)[0])


def _validate_markdown_links(errors: list[str]) -> int:
    markdown_files = _repository_files({".md"})
    for path in markdown_files:
        content = path.read_text(encoding="utf-8")
        for match in MARKDOWN_LINK_PATTERN.finditer(content):
            target = _local_link_target(match.group(1))
            if target is None:
                continue
            resolved = (path.parent / target).resolve()
            try:
                resolved.relative_to(REPOSITORY_ROOT.resolve())
            except ValueError:
                errors.append(
                    f"{path.relative_to(REPOSITORY_ROOT)}: local link escapes repository: {target}"
                )
                continue
            if not resolved.exists():
                errors.append(
                    f"{path.relative_to(REPOSITORY_ROOT)}: missing local link target: {target}"
                )
    return len(markdown_files)


def main() -> int:
    errors: list[str] = []
    yaml_count = _validate_yaml(errors)
    markdown_count = _validate_markdown_links(errors)

    if errors:
        print("Repository document validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        f"Repository documents valid: {yaml_count} YAML files parsed and "
        f"{markdown_count} Markdown files checked for local links."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
