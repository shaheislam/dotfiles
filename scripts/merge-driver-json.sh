#!/usr/bin/env bash
#
# merge-driver-json.sh - Deep-merge driver for JSON config files
#
# Custom git merge driver that deep-merges JSON files:
#   - Objects: recursively merge, theirs wins on scalar conflicts
#   - Arrays: union (deduplicated), preserving order from ours first
#   - Falls back to standard merge if JSON is invalid
#
# Primary target: .claude/settings.json where multiple worktrees
# add hooks, permission rules, and plugin entries independently.
#
# Registered via .gitattributes:
#   .claude/settings.json merge=json-merge
#
# Git config (set by setup.sh):
#   [merge "json-merge"]
#       name = Deep merge for JSON config files
#       driver = scripts/merge-driver-json.sh %A %O %B %L %P
#
# Parameters (from git):
#   $1 = %A = ours (current branch, result written here)
#   $2 = %O = base (common ancestor)
#   $3 = %B = theirs (other branch)
#   $4 = %L = conflict marker size
#   $5 = %P = path of the file
#
# Exit codes:
#   0 - Merge resolved successfully
#   1 - Unresolvable conflicts (fall back to git's default)

set -euo pipefail

OURS="$1"
BASE="$2"
THEIRS="$3"
# MARKER_SIZE="${4:-7}" # unused for JSON merge
FILE_PATH="${5:-unknown}"

log() {
    [[ "${MERGE_DRIVER_DEBUG:-}" == "1" ]] && echo "[merge-driver-json] $*" >&2 || true
}

log "Merging: $FILE_PATH"

cp "$OURS" "${OURS}.backup"

# Deep-merge using python3 (always available on macOS)
MERGE_RESULT=$(python3 -c "
import json
import sys

def deep_merge(base, ours, theirs):
    \"\"\"Three-way deep merge of JSON structures.\"\"\"
    if isinstance(ours, dict) and isinstance(theirs, dict):
        result = dict(ours)  # start with ours
        for key in theirs:
            if key in ours:
                base_val = base.get(key) if isinstance(base, dict) else None
                result[key] = deep_merge(base_val, ours[key], theirs[key])
            else:
                result[key] = theirs[key]
        return result

    elif isinstance(ours, list) and isinstance(theirs, list):
        # Union merge for arrays: keep all unique items
        # Use JSON serialization for hashability of complex items
        seen = set()
        result = []
        for item in ours:
            key = json.dumps(item, sort_keys=True) if isinstance(item, (dict, list)) else repr(item)
            if key not in seen:
                seen.add(key)
                result.append(item)
        for item in theirs:
            key = json.dumps(item, sort_keys=True) if isinstance(item, (dict, list)) else repr(item)
            if key not in seen:
                seen.add(key)
                result.append(item)
        return result

    else:
        # Scalar conflict: if ours changed from base, keep ours; otherwise take theirs
        if ours == base:
            return theirs
        return ours

try:
    with open('$OURS', 'r') as f:
        ours_data = json.load(f)
    with open('$BASE', 'r') as f:
        base_data = json.load(f)
    with open('$THEIRS', 'r') as f:
        theirs_data = json.load(f)
except (json.JSONDecodeError, ValueError) as e:
    print(f'PARSE_ERROR: {e}', file=sys.stderr)
    sys.exit(1)

try:
    merged = deep_merge(base_data, ours_data, theirs_data)
    with open('$OURS', 'w') as f:
        json.dump(merged, f, indent=2)
        f.write('\n')
    print('OK')
except Exception as e:
    print(f'MERGE_ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1) || true

if [[ "$MERGE_RESULT" == "OK" ]]; then
    rm -f "${OURS}.backup"
    log "JSON deep-merge successful for $FILE_PATH"
    exit 0
else
    log "JSON deep-merge failed: $MERGE_RESULT"
    log "Falling back to standard merge"
    cp "${OURS}.backup" "$OURS"
    rm -f "${OURS}.backup"
    # Fall back to standard 3-way merge with conflict markers
    git merge-file -L "ours" -L "base" -L "theirs" \
        "$OURS" "$BASE" "$THEIRS" 2>/dev/null || true
    exit 1
fi
