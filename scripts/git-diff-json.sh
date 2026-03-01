#!/usr/bin/env bash
#
# git-diff-json.sh - Textconv filter for JSON diffs
#
# Normalizes JSON before diffing: sorts keys and pretty-prints.
# This eliminates noise from key reordering and formatting differences,
# making diffs show only actual content changes.
#
# Registered via .gitattributes:
#   *.json diff=json
#
# Git config (set by setup.sh):
#   [diff "json"]
#       textconv = scripts/git-diff-json.sh
#
# Usage: git-diff-json.sh <file>

FILE="$1"

if [[ ! -f "$FILE" ]]; then
    exit 1
fi

# Use python3 (always available on macOS) to sort keys and pretty-print.
# Falls back to cat if the file isn't valid JSON (e.g., JSON with comments).
python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    json.dump(data, sys.stdout, indent=2, sort_keys=True)
    print()
except (json.JSONDecodeError, ValueError):
    with open(sys.argv[1]) as f:
        sys.stdout.write(f.read())
" "$FILE"
