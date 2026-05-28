#!/usr/bin/env bash
# UserPromptSubmit hook: set tmux window to red (actively working).
# TMUX_AGENT_TARGET is set by the claude wrapper (e.g. "@42").
[[ -z "${TMUX_AGENT_TARGET:-}" ]] && exit 0
tmux set-window-option -t "$TMUX_AGENT_TARGET" @wname_style '#[fg=#f7768e]' 2>/dev/null || true
