#!/bin/bash
set -euo pipefail
# Post-Compact Context Re-injection Hook (SessionStart, matcher: compact)
#
# After auto-compact strips conversation history, re-inject critical rules
# and current project state so Claude doesn't lose essential context.

# Output goes to Claude's context as additionalContext
cat <<'CONTEXT'
Post-compaction context reminder:
- Package manager: use bun/bunx (NEVER npm/npx/yarn/pnpm)
- Theme: Tokyo Night across all applications
- Shell: Fish primary, Zsh secondary
- Stow: all dotfiles symlinked via GNU Stow from ~/dotfiles
- tmux config: ONLY at ~/dotfiles/.tmux.conf (never .config/tmux/)
- Neovim: separate repo at ~/neovim (not part of dotfiles)
CONTEXT

# Add current git state if in a git repo
if git rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    MODIFIED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    echo "Git: branch=$BRANCH, $MODIFIED modified files"
fi

# Add active todo items if ralph-loop is active
if [ -f ".claude/ralph-loop.local.md" ]; then
    echo "Ralph-loop active in this session."
fi

# Re-inject beads subtask state after compaction
if command -v bd >/dev/null 2>&1 && [ -d ".beads" ]; then
    echo ""
    echo "=== Beads Context ==="

    # Show parent bead (the main ticket) if identifiable
    PARENT=$(bd list --status=in_progress --type=task --limit 1 2>/dev/null | head -1) || true
    if [ -n "$PARENT" ]; then
        echo "Parent: $PARENT"
    fi

    # Show in-progress subtasks
    IN_PROG=$(bd list --status=in_progress --limit 5 2>/dev/null) || true
    if [ -n "$IN_PROG" ]; then
        echo "In-progress:"
        echo "$IN_PROG"
    fi

    # Show what's ready to work on next
    READY=$(bd ready --limit 3 2>/dev/null) || true
    if [ -n "$READY" ]; then
        echo "Ready (unblocked):"
        echo "$READY"
    fi

    # Show recently closed (so agent knows what's done)
    CLOSED=$(bd list --status=closed --limit 3 2>/dev/null) || true
    if [ -n "$CLOSED" ]; then
        echo "Recently closed:"
        echo "$CLOSED"
    fi

    # Show blocked items (so agent knows what to unblock)
    BLOCKED=$(bd blocked 2>/dev/null) || true
    if [ -n "$BLOCKED" ]; then
        echo "Blocked:"
        echo "$BLOCKED"
    fi

    echo "Commands: bd ready | bd show ID | bd close ID | bd create --title=X --parent ID"
    echo "=== End Beads ==="
fi

exit 0
