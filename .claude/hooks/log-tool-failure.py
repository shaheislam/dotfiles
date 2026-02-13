#!/usr/bin/env python3
"""
PostToolUseFailure Hook — Log failed tool calls for pattern analysis.

Captures tool name, input, error message, and timestamp to a daily log file.
Helps identify recurring failures (wrong paths, syntax errors, missing tools).

Security: redacts potential secrets from logged data, sets 600 permissions.
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# Patterns that indicate secret content — redact these
SECRET_PATTERNS = re.compile(
    r"(password|secret|token|api.?key|auth|credential|private)"
    r"|([A-Za-z0-9+/]{40,})"  # Long base64-like strings
    r"|(eyJ[A-Za-z0-9_-]+\.)",  # JWT tokens
    re.IGNORECASE,
)

MAX_LOG_SIZE = 10 * 1024 * 1024  # 10MB per daily log


def redact(text: str) -> str:
    """Replace potential secrets with [REDACTED]."""
    if not text:
        return text
    return SECRET_PATTERNS.sub("[REDACTED]", text)


def main():
    try:
        input_data = json.load(sys.stdin)

        tool_name = input_data.get("tool_name", "unknown")
        tool_input = input_data.get("tool_input", {})
        error = input_data.get("error", "")

        # Build log entry with redacted values
        entry = {
            "timestamp": datetime.now().isoformat(),
            "session_id": input_data.get("session_id", ""),
            "tool_name": tool_name,
            "error": redact(str(error)[:500]),
        }

        # Add relevant input context based on tool type
        if tool_name == "Bash":
            entry["command"] = redact(tool_input.get("command", "")[:200])
        elif tool_name in ("Read", "Edit", "Write"):
            entry["file_path"] = tool_input.get("file_path", "")
        elif tool_name == "Grep":
            entry["pattern"] = tool_input.get("pattern", "")

        # Write to daily log file with restrictive permissions
        log_dir = Path.home() / ".claude" / "hooks" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        os.chmod(log_dir, 0o700)

        log_file = log_dir / f"tool-failures-{datetime.now():%Y-%m-%d}.jsonl"

        # Skip if log file is too large (prevents runaway disk usage)
        if log_file.exists() and log_file.stat().st_size > MAX_LOG_SIZE:
            sys.exit(0)

        with open(log_file, "a") as f:
            f.write(json.dumps(entry) + "\n")

        # Set restrictive permissions (owner read/write only)
        os.chmod(log_file, 0o600)

    except Exception:
        pass  # Never block on failure logging

    sys.exit(0)


if __name__ == "__main__":
    main()
