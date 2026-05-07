"""Shared changed-file extraction for Claude/OpenCode hook payloads."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable


DIRECT_PATH_KEYS = ("file_path", "filePath", "notebook_path", "path")
PATCH_TEXT_KEYS = ("patchText", "patch_text", "patch")
PATCH_HEADER_RE = re.compile(r"^\*\*\* (?:(Add|Update|Delete) File: (.+)|Move to: (.+))$")


def _unique(paths: Iterable[str]) -> list[str]:
    seen = set()
    result = []
    for path in paths:
        if not path or path in seen:
            continue
        seen.add(path)
        result.append(path)
    return result


def patch_paths(patch_text: Any, *, include_deleted: bool = True) -> list[str]:
    """Return file paths referenced by an apply_patch-style payload."""
    if not isinstance(patch_text, str):
        return []

    paths = []
    for line in patch_text.splitlines():
        match = PATCH_HEADER_RE.match(line)
        if not match:
            continue

        action, file_path, move_to = match.groups()
        if move_to:
            paths.append(move_to)
        elif action != "Delete" or include_deleted:
            paths.append(file_path)

    return paths


def changed_paths(tool_input: dict[str, Any], *, include_deleted: bool = True) -> list[str]:
    """Return direct and patch-derived paths from a tool_input object."""
    paths = []

    for key in DIRECT_PATH_KEYS:
        value = tool_input.get(key)
        if isinstance(value, str):
            paths.append(value)

    for key in PATCH_TEXT_KEYS:
        paths.extend(patch_paths(tool_input.get(key), include_deleted=include_deleted))

    return _unique(paths)


def changed_existing_paths(tool_input: dict[str, Any]) -> list[str]:
    """Return changed paths that still exist on disk after the tool ran."""
    return [path for path in changed_paths(tool_input, include_deleted=False) if Path(path).exists()]


def event_paths(event: dict[str, Any], *, include_deleted: bool = True, existing_only: bool = False) -> list[str]:
    tool_input = event.get("tool_input", {})
    if not isinstance(tool_input, dict):
        return []
    if existing_only:
        return changed_existing_paths(tool_input)
    return changed_paths(tool_input, include_deleted=include_deleted)


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract changed file paths from hook JSON on stdin")
    parser.add_argument("--exclude-deleted", action="store_true", help="omit Delete File patch targets")
    parser.add_argument("--existing-only", action="store_true", help="only print paths that exist on disk")
    parser.add_argument("--json", action="store_true", help="print a JSON array instead of newline-delimited paths")
    args = parser.parse_args()

    try:
        event = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    paths = event_paths(
        event,
        include_deleted=not args.exclude_deleted,
        existing_only=args.existing_only,
    )
    if args.json:
        print(json.dumps(paths))
    else:
        for path in paths:
            print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
