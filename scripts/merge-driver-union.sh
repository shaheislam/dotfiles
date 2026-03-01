#!/usr/bin/env bash
#
# merge-driver-union.sh - Union merge driver for documentation files
#
# Custom git merge driver that tries union merge for documentation files
# like CLAUDE.md. When both sides modify the same lines, union merge
# keeps both versions instead of creating conflict markers.
#
# Registered via .gitattributes:
#   CLAUDE.md merge=union-doc
#
# Git config (set by setup.sh):
#   [merge "union-doc"]
#       name = Union merge for documentation files
#       driver = scripts/merge-driver-union.sh %A %O %B %L %P
#       recursive = binary
#
# Parameters (from git):
#   $1 = %A = ours (current branch, result written here)
#   $2 = %O = base (common ancestor)
#   $3 = %B = theirs (other branch)
#   $4 = %L = conflict marker size (default 7)
#   $5 = %P = path of the file
#
# Strategy:
#   1. Try git merge-file --union (keeps both sides for conflicts)
#   2. If union merge produces clean result → exit 0
#   3. If residual conflict markers remain → attempt cleanup
#   4. If cleanup fails → fall back to standard merge (exit 1)
#
# Exit codes:
#   0 - Merge resolved successfully
#   1 - Unresolvable conflicts (fall back to git's default)

set -euo pipefail

OURS="$1"   # %A - result is written here
BASE="$2"   # %O
THEIRS="$3" # %B
MARKER_SIZE="${4:-7}"
FILE_PATH="${5:-unknown}"

# Log for debugging (only when MERGE_DRIVER_DEBUG=1)
log() {
    [[ "${MERGE_DRIVER_DEBUG:-}" == "1" ]] && echo "[merge-driver-union] $*" >&2 || true
}

log "Merging: $FILE_PATH"
log "  Ours:   $OURS"
log "  Base:   $BASE"
log "  Theirs: $THEIRS"

# Make a backup of ours in case we need to fall back
cp "$OURS" "${OURS}.backup"

# Try union merge: keeps both sides' changes for conflicting hunks
# --union: for conflicts, include lines from both sides
# Exit code from merge-file: 0 = clean, >0 = conflicts (but with --union,
# conflicts should be auto-resolved by keeping both sides)
MERGE_EXIT=0
git merge-file --union -L "ours" -L "base" -L "theirs" \
    "$OURS" "$BASE" "$THEIRS" 2>/dev/null || MERGE_EXIT=$?

# Check if any conflict markers remain after union merge
# (shouldn't happen with --union, but be safe)
if grep -q "^<<<<<<<\|^>>>>>>>\|^=======$\|^|||||||" "$OURS" 2>/dev/null; then
    log "Union merge left conflict markers, attempting cleanup"

    # Try to strip conflict markers, keeping all content from both sides
    # This handles the rare case where --union still leaves markers
    python3 -c "
import sys

with open('$OURS', 'r') as f:
    lines = f.readlines()

result = []
in_conflict = False
conflict_section = ''  # 'ours', 'base', 'theirs'

for line in lines:
    stripped = line.rstrip('\n')

    if stripped.startswith('<' * $MARKER_SIZE):
        in_conflict = True
        conflict_section = 'ours'
        continue
    elif stripped.startswith('|' * $MARKER_SIZE):
        conflict_section = 'base'
        continue
    elif stripped == '=' * $MARKER_SIZE:
        conflict_section = 'theirs'
        continue
    elif stripped.startswith('>' * $MARKER_SIZE):
        in_conflict = False
        conflict_section = ''
        continue

    # In a conflict: keep ours and theirs, skip base (avoid duplication)
    if in_conflict and conflict_section == 'base':
        continue

    result.append(line)

with open('$OURS', 'w') as f:
    f.writelines(result)
" 2>/dev/null

    # Verify cleanup worked - no markers should remain
    if grep -q "^<<<<<<<\|^>>>>>>>\|^=======$\|^|||||||" "$OURS" 2>/dev/null; then
        log "Cleanup failed, falling back to standard merge"
        cp "${OURS}.backup" "$OURS"
        rm -f "${OURS}.backup"
        # Re-run standard merge (no --union) to get proper conflict markers
        git merge-file -L "ours" -L "base" -L "theirs" \
            "$OURS" "$BASE" "$THEIRS" 2>/dev/null || true
        exit 1
    fi
fi

# Deduplicate consecutive identical lines that union merge may create
# (e.g., both sides added the same blank line or section header)
python3 -c "
with open('$OURS', 'r') as f:
    lines = f.readlines()

result = []
prev = None
for line in lines:
    # Skip consecutive duplicate lines (but preserve intentional blank lines)
    if line == prev and line.strip() != '':
        continue
    result.append(line)
    prev = line

with open('$OURS', 'w') as f:
    f.writelines(result)
" 2>/dev/null

rm -f "${OURS}.backup"
log "Union merge successful for $FILE_PATH"
exit 0
