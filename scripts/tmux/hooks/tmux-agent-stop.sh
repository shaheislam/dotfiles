#!/usr/bin/env bash
# Stop hook: Claude finished a response turn — green signals "done, check result."
# TMUX_AGENT_TARGET is set by the claude wrapper (e.g. "@42").
[[ -z "${TMUX_AGENT_TARGET:-}" ]] && exit 0
tmux set-window-option -t "$TMUX_AGENT_TARGET" @wname_style '#[fg=#9ece6a]' 2>/dev/null || true
