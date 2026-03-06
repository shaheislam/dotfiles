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
    IN_PROG=$(bd list --status=in_progress --limit 5 2>/dev/null)
    READY_COUNT=$(bd count --status=open 2>/dev/null || echo "0")
    if [ -n "$IN_PROG" ]; then
        echo ""
        echo "Beads subtasks in-progress:"
        echo "$IN_PROG"
        echo "Run 'bd ready' to see what to work on next."
    elif [ "$READY_COUNT" != "0" ]; then
        echo ""
        echo "Beads: $READY_COUNT open subtasks. Run 'bd ready' to continue."
    fi
fi

exit 0
