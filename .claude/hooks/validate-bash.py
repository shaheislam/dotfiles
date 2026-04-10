#!/usr/bin/env python3
"""
Bash Command Validation Hook
Validates bash commands before execution to ensure safety and suggest optimizations
"""

import json
import re
import sys

# Known-safe command prefixes that bypass blocklist checks entirely.
# These are idempotent operations used in devcontainer/worktree workflows.
ALLOWLIST_PREFIXES = [
    "devcontainer ",
    "devcontainer up",
    "git worktree ",
    "git worktree add",
    "git worktree list",
    "git worktree remove",
    "git worktree prune",
    "docker compose ",
    "colima ",
]

# Dangerous patterns to block
DANGEROUS_PATTERNS = [
    (r"\brm\s+-rf\s+/", "Dangerous rm -rf command detected"),
    (r"\bsudo\s+rm", "Sudo rm command detected - requires manual confirmation"),
    (r">\s*/dev/sd[a-z]", "Direct disk write detected"),
    (r"\bdd\s+.*of=/dev/", "Dangerous dd command to device"),
]

# Optimization suggestions
OPTIMIZATION_PATTERNS = [
    (r"\bgrep\b(?!.*\|)", "Consider using 'rg' (ripgrep) instead of 'grep' for better performance"),
    (r"\bfind\s+.*-name", "Consider using 'fd' instead of 'find' for faster file searching"),
    (r"\bcat\s+.*\|\s*grep", "Use 'rg' directly on the file instead of cat | grep"),
    (r"\bls\s+.*\|\s*grep", "Use 'ls pattern*' or 'fd pattern' instead of ls | grep"),
]


def validate_command(command: str) -> tuple[bool, list[str]]:
    """Validate a bash command and return (is_allowed, messages)"""
    messages = []
    blocked = False

    # Allowlist: known-safe commands bypass blocklist entirely
    stripped = command.strip()
    for prefix in ALLOWLIST_PREFIXES:
        if stripped.startswith(prefix):
            return True, []

    # Check for dangerous patterns
    for pattern, message in DANGEROUS_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            messages.append(f"🚨 BLOCKED: {message}")
            blocked = True

    # Check for optimization opportunities
    for pattern, message in OPTIMIZATION_PATTERNS:
        if re.search(pattern, command):
            messages.append(f"💡 TIP: {message}")

    return not blocked, messages


def main():
    try:
        # Read input from stdin
        input_data = json.loads(sys.stdin.read())

        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})

        if tool_name != "Bash":
            # Not a bash command, allow it
            sys.exit(0)

        command = tool_input.get("command", "")

        # Validate the command
        is_allowed, messages = validate_command(command)

        # Output messages appropriately
        if not is_allowed:
            # Blocked: use proper hook schema on stdout
            reason = "; ".join(m for m in messages if "BLOCKED" in m)
            print(json.dumps({"decision": "block", "reason": reason}))
            sys.exit(2)
        else:
            # Tips: print to stderr (visible to LLM, not parsed as hook JSON)
            for msg in messages:
                print(msg, file=sys.stderr)
            sys.exit(0)

    except Exception as e:
        # Fail closed: block command on unexpected errors
        print(f"validate-bash hook error (blocked): {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
