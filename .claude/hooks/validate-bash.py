#!/usr/bin/env python3
"""
Bash Command Validation Hook
Validates bash commands before execution to ensure safety and suggest optimizations
"""

import json
import re
import sys

# Dangerous patterns to block
DANGEROUS_PATTERNS = [
    (r'\brm\s+-rf\s+/', "Dangerous rm -rf command detected"),
    (r'\bsudo\s+rm', "Sudo rm command detected - requires manual confirmation"),
    (r'>\s*/dev/sd[a-z]', "Direct disk write detected"),
    (r'\bdd\s+.*of=/dev/', "Dangerous dd command to device"),
]

# Optimization suggestions
OPTIMIZATION_PATTERNS = [
    (r'\bgrep\b(?!.*\|)', "Consider using 'rg' (ripgrep) instead of 'grep' for better performance"),
    (r'\bfind\s+.*-name', "Consider using 'fd' instead of 'find' for faster file searching"),
    (r'\bcat\s+.*\|\s*grep', "Use 'rg' directly on the file instead of cat | grep"),
    (r'\bls\s+.*\|\s*grep', "Use 'ls pattern*' or 'fd pattern' instead of ls | grep"),
]

def validate_command(command: str) -> tuple[bool, list[str]]:
    """Validate a bash command and return (is_allowed, messages)"""
    messages = []
    blocked = False

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

        # Output any messages
        if messages:
            output = {
                "messages": messages,
                "command": command
            }
            print(json.dumps(output, indent=2))

        # Exit with appropriate code
        if not is_allowed:
            sys.exit(2)  # Block the command
        else:
            sys.exit(0)  # Allow the command

    except Exception as e:
        # Log error and allow command to proceed
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
