#!/usr/bin/env bash
# Launch OpenCode inside tmux with alternate-screen disabled so tmux copy-mode
# retains scrollback. Restores the prior setting when OpenCode exits.
set -euo pipefail

# Determine current window id so we can scope setw calls via tmux target
WINDOW=${TMUX_PANE:-}

restore_alternate_screen() {
	if [ -n "$WINDOW" ]; then
		tmux setw -t "$WINDOW" alternate-screen on >/dev/null 2>&1 || true
	else
		tmux setw -w alternate-screen on >/dev/null 2>&1 || true
	fi
}

trap restore_alternate_screen EXIT

if [ -n "$WINDOW" ]; then
	tmux setw -t "$WINDOW" alternate-screen off >/dev/null 2>&1 || true
else
	tmux setw -w alternate-screen off >/dev/null 2>&1 || true
fi

OPENCODE_DIR="$PWD" exec "$HOME/dotfiles/scripts/bin/oc"
