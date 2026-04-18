#!/usr/bin/env bash
# Wrapper for kill-pane that triggers worktree cleanup when the last pane closes.
# Called from tmux bind-key x.
#
# Captures window info BEFORE killing the pane, then runs cleanup
# asynchronously if it was the last pane (window will be destroyed).
#
# Usage:
#   tmux-kill-pane-cleanup.sh <session_name> <window_name> <window_panes>

SESSION_NAME="${1:-}"
WINDOW_NAME="${2:-}"
WINDOW_PANES="${3:-1}"
LOG_FILE="/tmp/tmux-worktree-cleanup.log"

# Kill the pane first (this is what the user expects)
tmux kill-pane

# If it was the last pane, the window is now gone - run cleanup in background
if [ "$WINDOW_PANES" = "1" ]; then
	nohup ~/dotfiles/scripts/tmux/tmux-worktree-cleanup.sh "$SESSION_NAME" "$WINDOW_NAME" \
		</dev/null >>"$LOG_FILE" 2>&1 &
fi
