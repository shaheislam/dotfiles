#!/usr/bin/env bash
# Stop hook: Claude finished a response turn, waiting for next input.
# TMUX_AGENT_TARGET is set by the claude wrapper (e.g. "@42").
tmux set-window-option -t "$TMUX_AGENT_TARGET" @wname_style '#[fg=#e0af68]' 2>/dev/null || true
