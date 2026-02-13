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
import subprocess
import sys
from pathlib import Path


FORMATTERS = {
    ".sh": (["shfmt", "-w", "-i", "4"], "shfmt"),
    ".bash": (["shfmt", "-w", "-i", "4"], "shfmt"),
    ".fish": (["fish_indent", "--write"], "fish_indent"),
    ".py": (["ruff", "format", "--quiet"], "ruff"),
}


def format_json(file_path: str) -> bool:
    """Format JSON using Python's built-in json module."""
    try:
        with open(file_path, "r") as f:
            data = json.load(f)
        with open(file_path, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        return True
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

        # Check if formatter is available
        if not subprocess.run(["command", "-v", cmd[0]], capture_output=True, shell=True).returncode == 0:
            # Try which instead
            try:
                subprocess.run(["which", cmd[0]], capture_output=True, check=True)
            except (subprocess.CalledProcessError, FileNotFoundError):
                sys.exit(0)  # Formatter not installed, skip silently

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
