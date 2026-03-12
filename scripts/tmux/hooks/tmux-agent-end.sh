#!/usr/bin/env bash
# SessionEnd hook: set green (complete), then clear after 30s.
# TMUX_AGENT_TARGET is set by the claude wrapper (e.g. "@42").

tmux set-window-option -t "$TMUX_AGENT_TARGET" @wname_style '#[fg=#9ece6a]' 2>/dev/null || true

# Background process: unset @wname_style after 30s so the window
# returns to its default color.
(
    sleep 30
    tmux set-window-option -t "$TMUX_AGENT_TARGET" -u @wname_style 2>/dev/null || true
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true
