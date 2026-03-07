#!/usr/bin/env bash
#
# merge-driver-jsonl.sh - JSONL merge driver for append-only line-based files
#
# Custom git merge driver for JSONL files like .beads/interactions.jsonl.
# Each line is an independent JSON object with a unique "id" field.
# Strategy: combine all lines, deduplicate by id, sort by created_at.
#
# Registered via .gitattributes:
#   .beads/*.jsonl merge=jsonl-merge
#
# Git config (set by setup.sh):
#   [merge "jsonl-merge"]
#       name = JSONL merge for append-only line files
#       driver = scripts/merge-driver-jsonl.sh %A %O %B %L %P
#
# Parameters (from git):
#   $1 = %A = ours (current branch, result written here)
#   $2 = %O = base (common ancestor)
#   $3 = %B = theirs (other branch)
#   $4 = %L = conflict marker size (unused)
#   $5 = %P = path of the file
#
# Strategy:
#   1. Collect all lines from ours + theirs
#   2. Deduplicate by JSON "id" field (ours wins on collision)
#   3. Sort by "created_at" for stable, chronological ordering
#   4. Write result to ours (%A)
#
# Exit codes:
#   0 - Merge resolved successfully
#   1 - Merge failed (fallback to git's default)

set -euo pipefail

OURS="$1"   # %A - result is written here
BASE="$2"   # %O
THEIRS="$3" # %B
# $4 = marker size (unused for JSONL)
FILE_PATH="${5:-unknown}"

log() {
    [[ "${MERGE_DRIVER_DEBUG:-}" == "1" ]] && echo "[merge-driver-jsonl] $*" >&2 || true
}

log "Merging: $FILE_PATH"
log "  Ours:   $OURS"
log "  Base:   $BASE"
log "  Theirs: $THEIRS"

# If both files are empty, nothing to do
if [[ ! -s "$OURS" && ! -s "$THEIRS" ]]; then
    log "Both sides empty, nothing to merge"
    exit 0
fi

# If only one side has content, use that
if [[ ! -s "$OURS" && -s "$THEIRS" ]]; then
    log "Only theirs has content, using theirs"
    cp "$THEIRS" "$OURS"
    exit 0
fi

if [[ -s "$OURS" && ! -s "$THEIRS" ]]; then
    log "Only ours has content, keeping ours"
    exit 0
fi

# Both sides have content - merge with dedup and sort
python3 -c "
import json
import sys

def load_jsonl(path):
    \"\"\"Load JSONL file, returning list of (id, line) tuples.\"\"\"
    entries = {}
    try:
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    entry_id = obj.get('id', '')
                    if entry_id:
                        entries[entry_id] = (obj, line)
                    else:
                        # No id field - use line content as key
                        entries[line] = (obj, line)
                except json.JSONDecodeError:
                    # Keep non-JSON lines as-is, keyed by content
                    entries[line] = (None, line)
    except FileNotFoundError:
        pass
    return entries

# Load both sides - ours wins on id collision
theirs = load_jsonl('$THEIRS')
ours = load_jsonl('$OURS')

# Merge: start with theirs, overlay ours (ours wins)
merged = {}
merged.update(theirs)
merged.update(ours)

# Sort by created_at if available, else by id
def sort_key(item):
    key, (obj, line) = item
    if obj and 'created_at' in obj:
        return (0, obj['created_at'], key)
    return (1, '', key)

sorted_entries = sorted(merged.items(), key=sort_key)

# Write result
with open('$OURS', 'w') as f:
    for key, (obj, line) in sorted_entries:
        f.write(line + '\n')

sys.exit(0)
" 2>/dev/null || EXIT_CODE=$?

if [[ "${EXIT_CODE:-0}" -ne 0 ]]; then
    log "Python merge failed, falling back to union merge"
    # Fallback: simple union merge (combine + sort + dedup by full line)
    {
        cat "$OURS"
        cat "$THEIRS"
    } | sort -u >"${OURS}.tmp"
    mv "${OURS}.tmp" "$OURS"
fi

log "JSONL merge successful for $FILE_PATH"
exit 0
