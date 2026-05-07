#!/usr/bin/env python3
"""
PreToolUse Hook (Edit|Write|MultiEdit|ApplyPatch) — Block edits to protected files.

Prevents accidental modification of critical configuration files.
Uses exit code 2 to block the operation and suggest alternatives.

Allowlist takes precedence over blocklist to avoid false positives.
"""

import os
import re
import sys

from lib.changed_files import changed_paths

# Allowlist — these patterns are always permitted (checked first)
ALLOWED_PATTERNS = [
    r"\.env\.example$",  # Template files are safe
    r"\.env\.sample$",
    r"\.env\.template$",
    r"bun\.lockb$",  # Bun's lockfile is fine
    r"Cargo\.lock$",  # Rust lockfile (not npm)
    r"poetry\.lock$",  # Python lockfile (not npm)
    r"Pipfile\.lock$",  # Python lockfile (not npm)
    r"go\.sum$",  # Go lockfile
    r"flake\.lock$",  # Nix lockfile
]

# Protected file patterns — edits to these require explicit intent
PROTECTED_PATTERNS = [
    # Security-sensitive (anchored to basename)
    (r"(^|/)\.env($|\.[^e])", "Environment files may contain secrets"),
    (r"\.pem$", "Certificate files"),
    (r"(^|/).*\.key$", "Key files"),
    (r"(^|/)id_rsa", "SSH private keys"),
    # Lock files (npm/yarn/pnpm only — use bun instead)
    (r"package-lock\.json$", "Use bun.lockb instead"),
    (r"(^|/)yarn\.lock$", "Use bun.lockb instead"),
    (r"pnpm-lock\.yaml$", "Use bun.lockb instead"),
    # Git internals
    (r"(^|/)\.git/", "Git internal files"),
    # Node modules
    (r"(^|/)node_modules/", "Generated dependency files"),
]


def main():
    try:
        import json

        input_data = json.load(sys.stdin)
        tool_input = input_data.get("tool_input", {})
        file_paths = changed_paths(tool_input)

        if not file_paths:
            sys.exit(0)

        for file_path in file_paths:
            # Resolve to absolute path to prevent traversal tricks
            file_path = os.path.realpath(file_path)

            # Allowlist check first — permitted files skip all guards
            if any(re.search(pattern, file_path) for pattern in ALLOWED_PATTERNS):
                continue

            for pattern, reason in PROTECTED_PATTERNS:
                if re.search(pattern, file_path):
                    print(
                        f"BLOCKED: Cannot edit protected file: {file_path}",
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
