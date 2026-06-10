#!/usr/bin/env python3
"""Validate Linux/WSL parity manifest coverage.

The manifest is intentionally simple YAML so it stays readable. This validator
uses PyYAML when available and a constrained fallback parser for CI/container
contexts that only have Python's standard library.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "scripts" / "parity" / "manifest.yml"
BREWFILE = ROOT / "homebrew" / "Brewfile"
PROFILES = ROOT / "scripts" / "profiles"
VALID_CATEGORIES = {"portable", "linux-alt", "macos-only", "gap"}


def load_manifest(path: Path) -> dict:
    try:
        import yaml  # type: ignore

        with path.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle)
        if not isinstance(data, dict):
            raise ValueError("manifest root must be a mapping")
        return data
    except ModuleNotFoundError:
        return load_manifest_fallback(path)


def load_manifest_fallback(path: Path) -> dict:
    data: dict[str, object] = {}
    current_section: str | None = None
    current_category: str | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line:
            continue

        if not raw_line.startswith(" ") and line.endswith(":"):
            current_section = line[:-1]
            current_category = None
            data[current_section] = {} if current_section in {"categories", "strategies"} else []
            continue

        if current_section == "categories":
            match = re.match(r"^  ([A-Za-z0-9_-]+):$", raw_line)
            if match:
                current_category = match.group(1)
                categories = data.setdefault("categories", {})
                assert isinstance(categories, dict)
                categories[current_category] = []
                continue
            match = re.match(r"^    - (.+)$", raw_line)
            if match and current_category:
                categories = data.setdefault("categories", {})
                assert isinstance(categories, dict)
                categories.setdefault(current_category, []).append(match.group(1).strip())
                continue

        if current_section == "strategies":
            match = re.match(r"^  ([^:]+):\s*(.+)$", raw_line)
            if match:
                strategies = data.setdefault("strategies", {})
                assert isinstance(strategies, dict)
                strategies[match.group(1).strip()] = match.group(2).strip()
                continue

        if current_section in {"targets", "accepted_gaps"}:
            match = re.match(r"^  - (.+)$", raw_line)
            if match:
                values = data.setdefault(current_section, [])
                assert isinstance(values, list)
                values.append(match.group(1).strip())
                continue

        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.+)$", raw_line)
        if match:
            data[match.group(1)] = match.group(2).strip()

    return data


def brewfile_entries(path: Path) -> set[str]:
    entries: set[str] = set()
    pattern = re.compile(r'^(?:brew|cask)\s+"([^"]+)"')
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = pattern.match(line)
        if match:
            entries.add(match.group(1))
    return entries


def profile_entries(path: Path) -> set[str]:
    entries: set[str] = set()
    for profile in path.glob("*.conf"):
        for raw_line in profile.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or line.startswith("["):
                continue
            if "=" not in line:
                continue
            name, enabled = line.split("=", 1)
            if enabled.strip() == "true":
                entries.add(name.strip())
    return entries


def categorized(manifest: dict) -> dict[str, str]:
    categories = manifest.get("categories")
    if not isinstance(categories, dict):
        raise ValueError("manifest must contain categories mapping")

    seen: dict[str, str] = {}
    for category, tools in categories.items():
        if category not in VALID_CATEGORIES:
            raise ValueError(f"unknown category: {category}")
        if not isinstance(tools, list):
            raise ValueError(f"category {category} must be a list")
        for tool in tools:
            if not isinstance(tool, str):
                raise ValueError(f"category {category} contains non-string entry")
            if tool in seen:
                raise ValueError(f"tool {tool!r} appears in both {seen[tool]} and {category}")
            seen[tool] = category
    return seen


def validate_strategies(manifest: dict, seen: dict[str, str]) -> list[str]:
    errors: list[str] = []
    strategies = manifest.get("strategies")
    if not isinstance(strategies, dict):
        return ["manifest must contain strategies mapping"]

    for tool, category in seen.items():
        if category in {"portable", "linux-alt"} and tool not in strategies:
            errors.append(f"missing strategy for {category} tool: {tool}")

    for tool in strategies:
        if tool not in seen:
            errors.append(f"strategy references uncategorized tool: {tool}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--brewfile", type=Path, default=BREWFILE)
    parser.add_argument("--profiles", type=Path, default=PROFILES)
    parser.add_argument("--report", action="store_true", help="print category counts")
    args = parser.parse_args()

    manifest = load_manifest(args.manifest)
    seen = categorized(manifest)
    expected = brewfile_entries(args.brewfile) | profile_entries(args.profiles)
    missing = sorted(expected - set(seen))
    parity_only = {
        "claude-hooks",
        "opencode-plugins",
        "skills",
        "subagents",
        "slash-commands",
        "mcp-config",
        "beads-memory",
        "tmux-agent-colors",
        "clipboard",
        "opencode-shared-server",
        "skill-toil-audit-scheduler",
        "wsl-open",
        "aerospace",
        "entire",
        "graphite",
        "linear",
        "macos-defaults",
        "reattach-to-user-namespace",
        "sketchybar",
        "launchd-plists",
    }
    stale = sorted(set(seen) - expected - parity_only)
    errors = validate_strategies(manifest, seen)

    if missing:
        errors.append("uncategorized install entries: " + ", ".join(missing))

    if args.report:
        counts = {category: list(seen.values()).count(category) for category in sorted(VALID_CATEGORIES)}
        for category, count in counts.items():
            print(f"{category}: {count}")
        if stale:
            print("stale-or-extra: " + ", ".join(stale))

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Parity manifest covers {len(expected)} install entries and {len(seen)} total parity items.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
