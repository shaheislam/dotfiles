#!/usr/bin/env python3
"""
PostToolUse Hook (Edit|Write) — Auto-format files after modification.

Detects file type and runs the appropriate formatter:
  .sh/.bash  → shfmt (if available)
  .fish      → fish_indent (if available)
  .py        → ruff format (if available)
  .json      → python json.tool (built-in)

Non-blocking: always exits 0. Outputs a systemMessage with format result.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


FORMATTERS = {
    ".sh": (["shfmt", "-w", "-i", "4"], "shfmt"),
    ".bash": (["shfmt", "-w", "-i", "4"], "shfmt"),
    ".fish": (["fish_indent", "--write"], "fish_indent"),
    ".py": (["ruff", "format", "--quiet"], "ruff"),
}


def format_json(file_path: str) -> bool:
    """Format JSON using Python's built-in json module with atomic write."""
    try:
        with open(file_path, "r") as f:
            original = f.read()
            data = json.loads(original)

        formatted = json.dumps(data, indent=2, ensure_ascii=False) + "\n"

        # Skip if already formatted (idempotent)
        if formatted == original:
            return False

        # Atomic write via temp file in same directory
        dir_path = os.path.dirname(file_path) or "."
        fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".json.tmp")
        try:
            with os.fdopen(fd, "w") as f:
                f.write(formatted)
            os.replace(tmp_path, file_path)
            return True
        except Exception:
            os.unlink(tmp_path)
            return False
    except (json.JSONDecodeError, OSError):
        return False


def main():
    try:
        input_data = json.load(sys.stdin)
        tool_input = input_data.get("tool_input", {})
        file_path = tool_input.get("file_path", "")

        if not file_path or not Path(file_path).exists():
            sys.exit(0)

        suffix = Path(file_path).suffix.lower()

        # JSON special case — use built-in
        if suffix == ".json":
            if format_json(file_path):
                print(json.dumps({"systemMessage": f"Auto-formatted {Path(file_path).name} (json)"}))
            sys.exit(0)

        # Check for known formatters
        formatter_info = FORMATTERS.get(suffix)
        if not formatter_info:
            sys.exit(0)

        cmd, name = formatter_info

        # Check if formatter is available via shutil.which
        if not shutil.which(cmd[0]):
            sys.exit(0)

        # Run formatter
        try:
            result = subprocess.run(
                cmd + [file_path],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                print(json.dumps({"systemMessage": f"Auto-formatted {Path(file_path).name} ({name})"}))
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass  # Skip silently

    except Exception:
        pass  # Never block on formatter errors

    sys.exit(0)


if __name__ == "__main__":
    main()
