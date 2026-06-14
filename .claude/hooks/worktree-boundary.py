#!/usr/bin/env python3
"""
PreToolUse Hook (Edit|Write|MultiEdit|ApplyPatch) — Enforce worktree boundary.

Blocks edits to paths outside the active worktree. Prevents the failure mode
where an agent launched in a worktree silently edits files in the main repo
or a sibling worktree (which happened during the SkillSpector work).

Boundary resolution (first that resolves to an existing directory wins):
    1. $WORKTREE_BOUNDARY      — explicit, set by gwt-ticket / gwt-dev
    2. $CLAUDE_PROJECT_DIR     — exported by Claude when launched with --add-dir
    3. git -C $PWD rev-parse --show-toplevel

Allowlist — paths under these prefixes are always permitted:
    - The boundary itself and its descendants
    - /tmp, /var/folders/**/T/** (macOS temp)
    - $HOME/.local/share, $HOME/.cache, $HOME/.local/state (ephemeral state)
    - $HOME/.claude/settings.json + settings.local.json (per CLAUDE.md #37029)
    - $HOME/neovim/** (per dotfiles CLAUDE.md exception)

Escape hatch:
    WORKTREE_BOUNDARY_OVERRIDE=1 — disables all checks for the session

Exit codes:
    0 — allowed
    2 — blocked (Claude/OpenCode propagates to refuse the tool call)
    Anything else from an unhandled exception is fail-open (return 0)
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from lib.changed_files import changed_paths


def resolve_boundary() -> Path | None:
    """Return the canonical worktree root, or None if we can't determine one."""
    for candidate in (os.environ.get("WORKTREE_BOUNDARY"), os.environ.get("CLAUDE_PROJECT_DIR")):
        if candidate and Path(candidate).is_dir():
            return Path(candidate).resolve()

    git = shutil.which("git")
    if not git:
        return None
    try:
        result = subprocess.run(
            [git, "-C", os.getcwd(), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (subprocess.SubprocessError, OSError):
        return None
    if result.returncode != 0:
        return None
    top = result.stdout.strip()
    return Path(top).resolve() if top else None


def allowed_prefixes(boundary: Path) -> list[Path]:
    home = Path.home()
    prefixes = [
        boundary,
        Path("/tmp"),
        Path("/private/tmp"),  # macOS symlinks /tmp here
        Path("/var/folders"),  # macOS per-user temp under TMPDIR
        home / ".local" / "share",
        home / ".cache",
        home / ".local" / "state",
        home / "neovim",
    ]
    return [p.resolve() for p in prefixes if p.exists()]


def allowed_exact_files(home: Path) -> list[Path]:
    return [
        home / ".claude" / "settings.json",
        home / ".claude" / "settings.local.json",
    ]


def is_allowed(target: Path, boundary: Path, prefixes: list[Path], exact_files: list[Path]) -> bool:
    try:
        target_resolved = target.resolve() if target.exists() else target.absolute()
    except (OSError, RuntimeError):
        target_resolved = target.absolute()

    if any(target_resolved == ef for ef in exact_files):
        return True

    for prefix in prefixes:
        try:
            target_resolved.relative_to(prefix)
            return True
        except ValueError:
            continue
    return False


def main() -> int:
    if os.environ.get("WORKTREE_BOUNDARY_OVERRIDE") == "1":
        return 0

    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # fail open on malformed input

    tool_input = event.get("tool_input", {})
    if not isinstance(tool_input, dict):
        return 0

    paths = changed_paths(tool_input)
    if not paths:
        return 0

    boundary = resolve_boundary()
    if boundary is None:
        return 0  # no boundary detectable, fail open

    home = Path.home()
    prefixes = allowed_prefixes(boundary)
    exact_files = allowed_exact_files(home)

    violations: list[tuple[Path, Path]] = []
    for raw in paths:
        target = Path(raw).expanduser()
        if not target.is_absolute():
            target = Path(os.getcwd()) / target
        if not is_allowed(target, boundary, prefixes, exact_files):
            violations.append((target, target.resolve() if target.exists() else target.absolute()))

    if not violations:
        return 0

    print("BLOCKED: Worktree boundary violation.", file=sys.stderr)
    print(f"  Boundary: {boundary}", file=sys.stderr)
    for raw, resolved in violations:
        print(f"  Target:   {raw} -> {resolved}", file=sys.stderr)
    print(
        "  Fix: edit a path under the boundary, or set WORKTREE_BOUNDARY_OVERRIDE=1"
        " for one-shot exceptions (e.g. ~/.claude/settings.json via jq).",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # Fail open on any unexpected error so we don't break user workflows.
        sys.exit(0)
