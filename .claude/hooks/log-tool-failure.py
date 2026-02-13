#!/usr/bin/env python3
"""
PostToolUseFailure Hook — Log failed tool calls for pattern analysis.

Captures tool name, input, error message, and timestamp to a daily log file.
Helps identify recurring failures (wrong paths, syntax errors, missing tools).
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path


def main():
    try:
        input_data = json.load(sys.stdin)

        tool_name = input_data.get("tool_name", "unknown")
        tool_input = input_data.get("tool_input", {})
        error = input_data.get("error", "")

        # Build log entry
        entry = {
            "timestamp": datetime.now().isoformat(),
            "session_id": input_data.get("session_id", ""),
            "tool_name": tool_name,
            "error": str(error)[:500],
        }

        # Add relevant input context based on tool type
        if tool_name == "Bash":
            entry["command"] = tool_input.get("command", "")[:200]
        elif tool_name in ("Read", "Edit", "Write"):
            entry["file_path"] = tool_input.get("file_path", "")
        elif tool_name == "Grep":
            entry["pattern"] = tool_input.get("pattern", "")

        # Write to daily log file
        log_dir = Path.home() / ".claude" / "hooks" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_dir / f"tool-failures-{datetime.now():%Y-%m-%d}.jsonl"

        with open(log_file, "a") as f:
            f.write(json.dumps(entry) + "\n")

    except Exception:
        pass  # Never block on failure logging

    sys.exit(0)


if __name__ == "__main__":
    main()
