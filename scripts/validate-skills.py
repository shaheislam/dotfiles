#!/usr/bin/env python3
"""Validate local SKILL.md files against the Agent Skills specification.

Reference: https://agentskills.io/specification

Checks:
  - SKILL.md exists in each skill directory
  - Valid YAML frontmatter with --- delimiters
  - Required fields: name, description
  - name: kebab-case, max 64 chars, matches directory name
  - description: non-empty, max 1024 chars, no angle brackets
  - Only allowed top-level keys (spec + Claude Code extensions)
  - compatibility: max 500 chars if present
  - harness pickup directories contain symlinks back to central skills
"""

import os
import re
import sys

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover - exercised in lightweight environments
    yaml = None

REPO_ROOT = os.path.dirname(os.path.dirname(__file__))
SKILL_ROOTS = [
    os.path.join(REPO_ROOT, "skills", "shared"),
    os.path.join(REPO_ROOT, "skills", "personal"),
    os.path.join(REPO_ROOT, "skills", "work"),
]

HARNESS_ROOTS = [
    os.path.join(REPO_ROOT, ".claude", "skills"),
    os.path.join(REPO_ROOT, ".agents", "skills"),
    os.path.join(REPO_ROOT, ".gemini", "skills"),
    os.path.join(REPO_ROOT, ".opencode", "skills"),
]

# Agent Skills spec allowed keys
SPEC_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}

# Claude Code extension keys (not in spec but used by the platform)
EXTENSION_KEYS = {"argument-hint", "arguments"}

ALLOWED_KEYS = SPEC_KEYS | EXTENSION_KEYS

NAME_PATTERN = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")


def parse_scalar(value):
    value = value.strip()
    if not value:
        return ""
    if value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    if value.lower() == "true":
        return True
    if value.lower() == "false":
        return False
    if re.fullmatch(r"-?\d+", value):
        return int(value)
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [parse_scalar(part.strip()) for part in inner.split(",")]
    return value


def parse_frontmatter(raw_text):
    if yaml is not None:
        return yaml.safe_load(raw_text)

    data = {}
    current_key = None

    for line in raw_text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue

        if line.startswith((" ", "\t")):
            if current_key is not None and data.get(current_key) is None:
                data[current_key] = {}
            continue

        if ":" not in line:
            raise ValueError(f"Unsupported frontmatter line without key/value separator: {line}")

        key, value = line.split(":", 1)
        current_key = key.strip()
        value = value.strip()
        data[current_key] = None if value == "" else parse_scalar(value)

    return data


def validate_skill(skill_dir):
    """Validate a single skill directory. Returns list of (level, message) tuples."""
    issues = []
    skill_name = os.path.basename(skill_dir)
    skill_md = os.path.join(skill_dir, "SKILL.md")

    if not os.path.isfile(skill_md):
        issues.append(("ERROR", "SKILL.md not found"))
        return issues

    with open(skill_md, "r") as f:
        content = f.read()

    # Check frontmatter delimiters
    if not content.startswith("---\n"):
        issues.append(("ERROR", "Missing YAML frontmatter (file must start with ---)"))
        return issues

    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        issues.append(("ERROR", "Malformed frontmatter (missing closing ---)"))
        return issues

    # Parse YAML
    try:
        frontmatter = parse_frontmatter(match.group(1))
    except Exception as e:
        issues.append(("ERROR", f"Invalid YAML: {e}"))
        return issues

    if not isinstance(frontmatter, dict):
        issues.append(("ERROR", "Frontmatter must be a YAML mapping"))
        return issues

    # Check required fields
    if "name" not in frontmatter:
        issues.append(("ERROR", "Missing required field: name"))
    if "description" not in frontmatter:
        issues.append(("ERROR", "Missing required field: description"))

    # Validate name
    name = frontmatter.get("name")
    if name is not None:
        if not isinstance(name, str):
            issues.append(("ERROR", f"name must be a string, got {type(name).__name__}"))
        else:
            if len(name) > 64:
                issues.append(("ERROR", f"name exceeds 64 chars ({len(name)})"))
            if not NAME_PATTERN.match(name):
                issues.append(("ERROR", f"name '{name}' is not valid kebab-case"))
            if "--" in name:
                issues.append(("ERROR", f"name '{name}' contains consecutive hyphens"))
            if name != skill_name:
                issues.append(("WARN", f"name '{name}' does not match directory '{skill_name}'"))

    # Validate description
    desc = frontmatter.get("description")
    if desc is not None:
        if not isinstance(desc, str):
            issues.append(("ERROR", f"description must be a string, got {type(desc).__name__}"))
        else:
            if len(desc) == 0:
                issues.append(("ERROR", "description must not be empty"))
            if len(desc) > 1024:
                issues.append(("WARN", f"description exceeds 1024 chars ({len(desc)})"))
            if "<" in desc or ">" in desc:
                issues.append(("WARN", "description contains angle brackets"))

    # Validate compatibility
    compat = frontmatter.get("compatibility")
    if compat is not None:
        if not isinstance(compat, str):
            issues.append(("ERROR", f"compatibility must be a string, got {type(compat).__name__}"))
        elif len(compat) > 500:
            issues.append(("WARN", f"compatibility exceeds 500 chars ({len(compat)})"))

    # Check for non-standard keys
    extra_keys = set(frontmatter.keys()) - ALLOWED_KEYS
    if extra_keys:
        issues.append(("INFO", f"Non-standard keys: {', '.join(sorted(extra_keys))}"))

    return issues


def iter_skill_dirs(root_dir):
    if not os.path.isdir(root_dir):
        return []

    return sorted(
        os.path.join(root_dir, d)
        for d in os.listdir(root_dir)
        if os.path.isdir(os.path.join(root_dir, d)) and not d.startswith(".")
    )


def central_skill_map():
    skills = {}
    for root in SKILL_ROOTS:
        for skill_dir in iter_skill_dirs(root):
            skills[os.path.basename(skill_dir)] = os.path.realpath(skill_dir)
    return skills


def validate_harness_links(skills):
    issues = []
    for root in HARNESS_ROOTS:
        rel_root = os.path.relpath(root, REPO_ROOT)
        if not os.path.isdir(root):
            issues.append(("ERROR", f"{rel_root} missing; run scripts/sync-skills-harnesses.sh"))
            continue

        for name, source in skills.items():
            target = os.path.join(root, name)
            rel_target = os.path.relpath(target, REPO_ROOT)
            if not os.path.islink(target):
                issues.append(("ERROR", f"{rel_target} is not a symlink to central skills"))
                continue
            if os.path.realpath(target) != source:
                issues.append(("ERROR", f"{rel_target} points to {os.path.realpath(target)}, expected {source}"))

    return issues


def main():
    available_roots = [root for root in SKILL_ROOTS if os.path.isdir(root)]
    if not available_roots:
        print("No skills directories found.", file=sys.stderr)
        sys.exit(1)

    skills = []
    for root in available_roots:
        for skill_dir in iter_skill_dirs(root):
            skills.append((root, skill_dir))

    total = len(skills)
    errors = 0
    warnings = 0
    clean = 0

    for root, skill_dir in skills:
        skill = os.path.basename(skill_dir)
        display_name = os.path.relpath(skill_dir, REPO_ROOT)
        issues = validate_skill(skill_dir)

        if not issues:
            clean += 1
            if "--verbose" in sys.argv:
                print(f"  OK  {display_name}")
            continue

        has_error = any(level == "ERROR" for level, _ in issues)
        has_warn = any(level == "WARN" for level, _ in issues)

        if has_error:
            errors += 1
        elif has_warn:
            warnings += 1
        else:
            clean += 1

        for level, msg in issues:
            if level == "INFO" and "--verbose" not in sys.argv:
                continue
            symbol = {"ERROR": "FAIL", "WARN": "WARN", "INFO": "INFO"}[level]
            print(f"  {symbol}  {display_name}: {msg}")

    print(f"\n{total} skills validated: {clean} clean, {warnings} warnings, {errors} errors")

    harness_issues = validate_harness_links(central_skill_map())
    if harness_issues:
        print("\nHarness link validation:")
        for level, msg in harness_issues:
            symbol = {"ERROR": "FAIL", "WARN": "WARN", "INFO": "INFO"}.get(level, level)
            print(f"  {symbol}  {msg}")
            if level == "ERROR":
                errors += 1
    else:
        print("Harness link validation: OK")

    if errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
