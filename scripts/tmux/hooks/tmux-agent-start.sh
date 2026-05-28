#!/usr/bin/env bash
# SessionStart hook: set tmux window to orange (waiting for first prompt).
# TMUX_AGENT_TARGET is set by the claude wrapper (e.g. "@42").
[[ -z "${TMUX_AGENT_TARGET:-}" ]] && exit 0
tmux set-window-option -t "$TMUX_AGENT_TARGET" @wname_style '#[fg=#e0af68]' 2>/dev/null || true
