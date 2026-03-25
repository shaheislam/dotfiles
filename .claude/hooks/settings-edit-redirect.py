#!/usr/bin/env python3
"""
PreToolUse hook: redirect Edit/Write on Claude settings files to Bash.

Workaround for https://github.com/anthropics/claude-code/issues/37029
Even with --dangerously-skip-permissions, edits to ~/.claude/settings*.json
trigger a permission prompt. This hook blocks the Edit/Write and instructs
Claude to use jq or python3 via Bash instead.
"""

import json
import os
import sys


# Files that trigger the bug (expanded at runtime)
PROTECTED_SETTINGS = [
    os.path.expanduser("~/.claude/settings.json"),
    os.path.expanduser("~/.claude/settings.local.json"),
]

# Pre-resolve to real paths for symlink-safe comparison
PROTECTED_REAL = [os.path.realpath(p) for p in PROTECTED_SETTINGS]


def is_settings_file(file_path: str) -> bool:
    """Check if a file path resolves to a protected Claude settings file."""
    if not file_path:
        return False
    resolved = os.path.realpath(os.path.expanduser(file_path))
    return resolved in PROTECTED_REAL


def main():
    try:
        data = json.load(sys.stdin)
        tool_name = data.get("tool_name", "")
        tool_input = data.get("tool_input", {})

        if tool_name not in ("Edit", "Write"):
            sys.exit(0)

        file_path = tool_input.get("file_path", "")
        if not is_settings_file(file_path):
            sys.exit(0)

        resolved = os.path.realpath(os.path.expanduser(file_path))
        basename = os.path.basename(resolved)

        # Block and redirect to Bash
        print(
            f"BLOCKED: Edit/Write on {basename} triggers a permission prompt "
            f"even in --dangerously-skip-permissions mode (bug #37029).\n"
            f"Use Bash with jq to modify the file instead. Examples:\n"
            f"  # Set a top-level key:\n"
            f"  jq '.key = \"value\"' '{resolved}' > /tmp/_settings.tmp "
            f"&& mv /tmp/_settings.tmp '{resolved}'\n"
            f"  # Set a nested key:\n"
            f"  jq '.parent.child = \"value\"' '{resolved}' > /tmp/_settings.tmp "
            f"&& mv /tmp/_settings.tmp '{resolved}'\n"
            f"  # Delete a key:\n"
            f"  jq 'del(.key)' '{resolved}' > /tmp/_settings.tmp "
            f"&& mv /tmp/_settings.tmp '{resolved}'",
            file=sys.stderr,
        )
        sys.exit(2)

    except Exception:
        # Fail open — don't block if the hook itself errors
        sys.exit(0)


if __name__ == "__main__":
    main()
