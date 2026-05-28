#!/usr/bin/env bash
# SessionEnd hook: Claude exited — clear color immediately (no agent to return to).
# TMUX_AGENT_TARGET is set by the claude wrapper (e.g. "@42").
[[ -z "${TMUX_AGENT_TARGET:-}" ]] && exit 0
tmux set-window-option -t "$TMUX_AGENT_TARGET" -u @wname_style 2>/dev/null || true
