#!/usr/bin/env bash
# Auto-cleanup git worktree and local branch when a tmux window closes.
#
# Called from tmux key bindings (kill-pane/kill-window) when the last pane
# in a window is being killed. Only acts for dotfiles/neovim sessions where
# the window name maps to a worktree branch.
#
# Safety checks:
# - Skips protected branches (main, master, develop)
# - Skips windows with uncommitted changes (shows warning)
# - Only acts on sessions for configured repos
# - Verifies worktree exists before attempting removal
#
# Usage:
#   tmux-worktree-cleanup.sh <session_name> <window_name>

set -euo pipefail

SESSION_NAME="${1:-}"
WINDOW_NAME="${2:-}"

if [[ -z "$SESSION_NAME" ]] || [[ -z "$WINDOW_NAME" ]]; then
    exit 0
fi

LOG_FILE="/tmp/tmux-worktree-cleanup.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

# Map session names to their repo root directories
declare -A SESSION_REPOS
SESSION_REPOS[dotfiles]="$HOME/dotfiles"
SESSION_REPOS[neovim]="$HOME/neovim"

# Check if this session is one we should auto-cleanup
REPO_ROOT="${SESSION_REPOS[$SESSION_NAME]:-}"
if [[ -z "$REPO_ROOT" ]]; then
    exit 0
fi

if [[ ! -d "$REPO_ROOT/.git" ]] && [[ ! -f "$REPO_ROOT/.git" ]]; then
    log "SKIP: $REPO_ROOT is not a git repository"
    exit 0
fi

REPO_NAME=$(basename "$REPO_ROOT")

# Skip special window names that aren't worktree branches
case "$WINDOW_NAME" in
    base|main|master|develop|fish|bash|zsh|"")
        exit 0
        ;;
esac

# The branch name is the window name (gwt-parallel names windows after branches,
# replacing / with -). The worktree dir also uses this same format.
BRANCH_NAME="$WINDOW_NAME"
WORKTREE_PATH="$REPO_ROOT/../${REPO_NAME}-${BRANCH_NAME}"

# Check if the worktree actually exists
if [[ ! -d "$WORKTREE_PATH" ]]; then
    log "SKIP: No worktree found at $WORKTREE_PATH for window '$WINDOW_NAME'"
    exit 0
fi

# Verify this is actually a git worktree (not the main repo)
RESOLVED_WORKTREE=$(cd "$WORKTREE_PATH" && pwd -P 2>/dev/null || echo "")
RESOLVED_REPO=$(cd "$REPO_ROOT" && pwd -P 2>/dev/null || echo "")

if [[ "$RESOLVED_WORKTREE" == "$RESOLVED_REPO" ]]; then
    log "SKIP: $WORKTREE_PATH is the main repo, not a worktree"
    exit 0
fi

# Verify it's a worktree by checking if git recognizes it
if ! (cd "$WORKTREE_PATH" && git rev-parse --git-dir >/dev/null 2>&1); then
    log "SKIP: $WORKTREE_PATH is not a git directory"
    exit 0
fi

# Get the branch name from the worktree metadata (more reliable than window name)
# Use exact line match (^worktree path$) to avoid substring matches
# e.g., "dotfiles-tmuxwindow" must not match "dotfiles-tmuxwindowclose2"
ACTUAL_BRANCH=$(cd "$REPO_ROOT" && git worktree list --porcelain 2>/dev/null | \
    grep -A2 "^worktree ${RESOLVED_WORKTREE}$" | grep "^branch " | sed 's|^branch refs/heads/||')

if [[ -z "$ACTUAL_BRANCH" ]]; then
    # Try with the non-resolved path (exact match)
    RESOLVED_WT_PATH=$(cd "$WORKTREE_PATH" 2>/dev/null && pwd -P || echo "$WORKTREE_PATH")
    ACTUAL_BRANCH=$(cd "$REPO_ROOT" && git worktree list --porcelain 2>/dev/null | \
        grep -A2 "^worktree ${RESOLVED_WT_PATH}$" | grep "^branch " | sed 's|^branch refs/heads/||')
fi

if [[ -z "$ACTUAL_BRANCH" ]]; then
    log "SKIP: Could not determine branch for worktree $WORKTREE_PATH"
    exit 0
fi

# Don't delete protected branches
case "$ACTUAL_BRANCH" in
    main|master|develop)
        log "SKIP: Protected branch $ACTUAL_BRANCH"
        exit 0
        ;;
esac

log "CLEANUP: session=$SESSION_NAME window=$WINDOW_NAME branch=$ACTUAL_BRANCH worktree=$WORKTREE_PATH"

# Check for uncommitted changes before removing
if (cd "$WORKTREE_PATH" && git status --porcelain 2>/dev/null | grep -q .); then
    log "WARNING: Worktree $WORKTREE_PATH has uncommitted changes - skipping cleanup"
    tmux display-message -d 5000 \
        "#[fg=#f38ba8]Worktree '$ACTUAL_BRANCH' has uncommitted changes - skipping auto-cleanup. Use gwtr to remove manually.#[default]" \
        2>/dev/null || true
    exit 0
fi

# Stop any running devcontainer for this worktree
INSTANCE_NAME=$(echo "${REPO_NAME}-${BRANCH_NAME}" | tr '/' '-')
INSTANCE_BASE="$HOME/.devcontainer/instances"
WORKSPACE_BASE="$HOME/.devcontainer/workspaces"

if command -v docker >/dev/null 2>&1; then
    CONTAINER_ID=$(docker ps -q --filter "name=$INSTANCE_NAME" 2>/dev/null || true)
    if [[ -n "$CONTAINER_ID" ]]; then
        log "Stopping container for instance: $INSTANCE_NAME"
        docker stop "$CONTAINER_ID" >/dev/null 2>&1 || true
    fi
fi

# Remove devcontainer instance/workspace directories if they exist
if [[ -d "$INSTANCE_BASE/$INSTANCE_NAME" ]]; then
    rm -rf "${INSTANCE_BASE:?}/$INSTANCE_NAME" 2>/dev/null || true
    log "Removed devcontainer instance: $INSTANCE_NAME"
fi
if [[ -d "$WORKSPACE_BASE/$INSTANCE_NAME" ]]; then
    rm -rf "${WORKSPACE_BASE:?}/$INSTANCE_NAME" 2>/dev/null || true
    log "Removed devcontainer workspace: $INSTANCE_NAME"
fi

# Remove the worktree
cd "$REPO_ROOT"
if git worktree remove --force "$WORKTREE_PATH" 2>/dev/null; then
    log "Removed worktree: $WORKTREE_PATH"
else
    log "ERROR: Failed to remove worktree: $WORKTREE_PATH"
    tmux display-message -d 3000 \
        "#[fg=#f38ba8]Failed to remove worktree '$ACTUAL_BRANCH'#[default]" \
        2>/dev/null || true
    exit 1
fi

# Delete the local branch
if git branch -D "$ACTUAL_BRANCH" 2>/dev/null; then
    log "Deleted branch: $ACTUAL_BRANCH"
else
    log "WARNING: Could not delete branch: $ACTUAL_BRANCH"
fi

# Prune worktrees
git worktree prune 2>/dev/null || true

# Show success notification
tmux display-message -d 3000 \
    "#[fg=#a6e3a1]Cleaned up worktree + branch: $ACTUAL_BRANCH#[default]" \
    2>/dev/null || true

log "DONE: Cleaned up worktree and branch for $ACTUAL_BRANCH"
