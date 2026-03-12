#!/usr/bin/env bash
# Notification hook: set orange on permission/idle prompts only.
# Don't override working state (red) for other notification types.
# TMUX_AGENT_TARGET is set by the claude wrapper (e.g. "@42").
#
# Claude Code pipes notification JSON to stdin with fields like
# "title", "body", "action". Permission prompts contain "permission"
# in the title/body.

INPUT=$(cat)

# Only set orange for permission-related or idle notifications
if echo "$INPUT" | grep -qiE 'permission|approve|waiting for'; then
    tmux set-window-option -t "$TMUX_AGENT_TARGET" @wname_style '#[fg=#e0af68]' 2>/dev/null || true
fi
