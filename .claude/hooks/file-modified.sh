#!/bin/bash
# File Modification Hook - PostToolUse (Edit|Write)
# Lightweight syntax validation for modified files.
# PERF: Uses single jq parse instead of two Python subprocesses (~200ms saved).
# JSON validation removed — auto-format.py already handles JSON formatting.

INPUT=$(cat)

# Single jq parse for both fields (one fork instead of two python3 forks)
read -r TOOL_NAME FILE_PATH < <(echo "$INPUT" | jq -r '[.tool_name // "", .tool_input.file_path // ""] | @tsv' 2>/dev/null) || exit 0

[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Python syntax check (skip if auto-format.py already ran ruff)
if [[ "$FILE_PATH" == *.py ]]; then
    if ! python3 -m py_compile "$FILE_PATH" 2>/dev/null; then
        echo "Python syntax error in $(basename "$FILE_PATH")"
    fi
fi

exit 0
