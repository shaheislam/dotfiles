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
"""

import os
import re
import sys
import yaml

SKILLS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".claude", "skills")

# Agent Skills spec allowed keys
SPEC_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}

# Claude Code extension keys (not in spec but used by the platform)
EXTENSION_KEYS = {"argument-hint", "arguments"}

ALLOWED_KEYS = SPEC_KEYS | EXTENSION_KEYS

NAME_PATTERN = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")


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
        frontmatter = yaml.safe_load(match.group(1))
    except yaml.YAMLError as e:
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


def main():
    if not os.path.isdir(SKILLS_DIR):
        print(f"Skills directory not found: {SKILLS_DIR}", file=sys.stderr)
        sys.exit(1)

    skills = sorted(
        d for d in os.listdir(SKILLS_DIR) if os.path.isdir(os.path.join(SKILLS_DIR, d)) and not d.startswith(".")
    )

    total = len(skills)
    errors = 0
    warnings = 0
    clean = 0

    for skill in skills:
        skill_dir = os.path.join(SKILLS_DIR, skill)
        issues = validate_skill(skill_dir)

        if not issues:
            clean += 1
            if "--verbose" in sys.argv:
                print(f"  OK  {skill}")
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
            print(f"  {symbol}  {skill}: {msg}")

    print(f"\n{total} skills validated: {clean} clean, {warnings} warnings, {errors} errors")

    if errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
