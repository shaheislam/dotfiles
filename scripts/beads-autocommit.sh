#!/usr/bin/env bash
#
# beads-autocommit.sh - Auto-commit interactions.jsonl on the main worktree
#
# Problem: bd audit record writes to interactions.jsonl in the main worktree
# (where the Dolt database lives), even when called from a branch worktree.
# This leaves interactions.jsonl perpetually dirty on main.
#
# Solution: After audit writes, commit interactions.jsonl on main automatically.
# Safe to call from any worktree - resolves main worktree via git common dir.
#
# Usage:
#   beads-autocommit.sh              # auto-commit if dirty
#   beads-autocommit.sh --check      # just check, don't commit
#
# Exit codes:
#   0 - Committed (or nothing to commit)
#   1 - Error
#   2 - Skipped (merge in progress, --check mode found dirty)

set -euo pipefail

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

# Resolve the main worktree path (where .git is a directory, not a file)
resolve_main_worktree() {
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1

    # If git-common-dir is ".git", we're already in the main worktree
    if [[ "$git_common_dir" == ".git" ]]; then
        pwd
        return 0
    fi

    # Otherwise it's an absolute path like /path/to/main/.git
    # Strip the trailing /.git (or /worktrees/xxx)
    local main_git="${git_common_dir}"
    # git-common-dir points to the .git dir of the main worktree
    dirname "$main_git"
}

MAIN_WORKTREE=$(resolve_main_worktree)
if [[ -z "$MAIN_WORKTREE" ]]; then
    echo "Error: could not resolve main worktree" >&2
    exit 1
fi

INTERACTIONS="$MAIN_WORKTREE/.beads/interactions.jsonl"

if [[ ! -f "$INTERACTIONS" ]]; then
    exit 0
fi

# Check if interactions.jsonl has uncommitted changes on main
if git -C "$MAIN_WORKTREE" diff --quiet -- .beads/interactions.jsonl 2>/dev/null &&
    git -C "$MAIN_WORKTREE" diff --cached --quiet -- .beads/interactions.jsonl 2>/dev/null; then
    # Clean - nothing to do
    exit 0
fi

if $CHECK_ONLY; then
    echo "dirty"
    exit 2
fi

# Skip auto-commit if main is in a merge state - the merge commit will include it
if [[ -f "$MAIN_WORKTREE/.git/MERGE_HEAD" ]]; then
    # Stage it so the merge commit picks it up
    git -C "$MAIN_WORKTREE" add .beads/interactions.jsonl 2>/dev/null || true
    exit 0
fi

# Auto-commit only interactions.jsonl (--only ensures no other staged files are included)
git -C "$MAIN_WORKTREE" add .beads/interactions.jsonl 2>/dev/null || exit 1
git -C "$MAIN_WORKTREE" commit --only .beads/interactions.jsonl \
    -m "beads: auto-commit interactions.jsonl" \
    --no-verify 2>/dev/null || exit 1
