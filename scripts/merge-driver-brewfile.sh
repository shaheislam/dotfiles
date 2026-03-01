#!/usr/bin/env bash
#
# merge-driver-brewfile.sh - Union merge driver for Brewfile
#
# Extends the standard union merge with Brewfile-specific deduplication.
# After union merge, removes duplicate tap/brew/cask/mas lines that may
# appear when both branches add the same package independently.
#
# Registered via .gitattributes:
#   homebrew/Brewfile merge=brewfile
#
# Git config (set by setup.sh):
#   [merge "brewfile"]
#       name = Union merge for Brewfile
#       driver = scripts/merge-driver-brewfile.sh %A %O %B %L %P
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
MARKER_SIZE="${4:-7}"
FILE_PATH="${5:-unknown}"

log() {
    [[ "${MERGE_DRIVER_DEBUG:-}" == "1" ]] && echo "[merge-driver-brewfile] $*" >&2 || true
}

log "Merging: $FILE_PATH"

cp "$OURS" "${OURS}.backup"

# Step 1: Union merge (keeps both sides)
MERGE_EXIT=0
git merge-file --union -L "ours" -L "base" -L "theirs" \
    "$OURS" "$BASE" "$THEIRS" 2>/dev/null || MERGE_EXIT=$?

# Step 2: Check for residual conflict markers
if grep -q "^<<<<<<<\|^>>>>>>>\|^=======$\|^|||||||" "$OURS" 2>/dev/null; then
    log "Union merge left conflict markers, falling back"
    cp "${OURS}.backup" "$OURS"
    rm -f "${OURS}.backup"
    git merge-file -L "ours" -L "base" -L "theirs" \
        "$OURS" "$BASE" "$THEIRS" 2>/dev/null || true
    exit 1
fi

# Step 3: Deduplicate Brewfile entries (tap, brew, cask, mas lines)
# Keeps first occurrence, preserves comments and blank lines
python3 -c "
with open('$OURS', 'r') as f:
    lines = f.readlines()

seen = set()
result = []

for line in lines:
    stripped = line.strip()

    # Always keep comments, blank lines, and non-declaration lines
    if not stripped or stripped.startswith('#'):
        result.append(line)
        continue

    # For tap/brew/cask/mas declarations, deduplicate by the declaration itself
    # Normalize: strip trailing comments for dedup key
    dedup_key = stripped.split('#')[0].strip()

    if dedup_key.startswith(('tap ', 'brew ', 'cask ', 'mas ')):
        if dedup_key in seen:
            continue
        seen.add(dedup_key)

    result.append(line)

with open('$OURS', 'w') as f:
    f.writelines(result)
" 2>/dev/null

rm -f "${OURS}.backup"
log "Brewfile merge successful for $FILE_PATH"
exit 0
