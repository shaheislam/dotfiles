#!/bin/bash
# File Modification Hook - PostToolUse (Edit|Write|MultiEdit|ApplyPatch)
# Lightweight syntax validation for modified files.
# JSON validation removed — auto-format.py already handles JSON formatting.

INPUT=$(cat)

while IFS= read -r FILE_PATH; do
    [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && continue

    # Python syntax check (skip if auto-format.py already ran ruff)
    if [[ "$FILE_PATH" == *.py ]]; then
        if ! python3 -m py_compile "$FILE_PATH" 2>/dev/null; then
            echo "Python syntax error in $(basename "$FILE_PATH")"
        fi
    fi
done < <(python3 "$(dirname "${BASH_SOURCE[0]}")/lib/changed_files.py" --exclude-deleted --existing-only <<<"$INPUT" 2>/dev/null || true)

exit 0
