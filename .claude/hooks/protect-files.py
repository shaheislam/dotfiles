#!/usr/bin/env python3
"""
PreToolUse Hook (Edit|Write) — Block edits to protected files.

Prevents accidental modification of critical configuration files.
Uses exit code 2 to block the operation and suggest alternatives.
"""

import json
import re
import sys

# Protected file patterns — edits to these require explicit intent
PROTECTED_PATTERNS = [
    # Security-sensitive
    (r"\.env($|\.)", "Environment files may contain secrets"),
    (r"\.pem$", "Certificate files"),
    (r"\.key$", "Key files"),
    (r"id_rsa", "SSH private keys"),
    # Lock files (should be auto-generated)
    (r"package-lock\.json$", "Use bun.lockb instead"),
    (r"yarn\.lock$", "Use bun.lockb instead"),
    (r"pnpm-lock\.yaml$", "Use bun.lockb instead"),
    # Git internals
    (r"\.git/", "Git internal files"),
    # Node modules
    (r"node_modules/", "Generated dependency files"),
]


def main():
    try:
        input_data = json.load(sys.stdin)
        tool_input = input_data.get("tool_input", {})
        file_path = tool_input.get("file_path", "")

        if not file_path:
            sys.exit(0)

        for pattern, reason in PROTECTED_PATTERNS:
            if re.search(pattern, file_path):
                print(
                    f"🛡️ BLOCKED: Cannot edit protected file: {file_path}",
                    file=sys.stderr,
                )
                print(f"   Reason: {reason}", file=sys.stderr)
                sys.exit(2)

        sys.exit(0)

    except Exception:
        # Fail open — don't block edits on hook errors
        sys.exit(0)


if __name__ == "__main__":
    main()
