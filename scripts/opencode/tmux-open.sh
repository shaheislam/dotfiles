#!/usr/bin/env bash
# Launch OpenCode inside tmux with alternate-screen disabled so tmux copy-mode
# retains scrollback. Restores the prior setting when OpenCode exits.
set -euo pipefail

# Determine current pane/window so local tmux state follows this OpenCode UI.
WINDOW=${TMUX_PANE:-}
STYLE_TARGET=""
SYNC_PID=""

if [ -n "${TMUX:-}" ]; then
    STYLE_TARGET="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
    export TMUX_AGENT_TARGET="$STYLE_TARGET"
fi

if [ -z "$STYLE_TARGET" ]; then
    STYLE_TARGET="$WINDOW"
fi

status_style() {
    case "$1" in
    busy | running | thinking | streaming | error)
        printf '%s\n' '#[fg=#f7768e]'
        ;;
    idle)
        printf '%s\n' '#[fg=#9ece6a]'
        ;;
    *)
        printf '%s\n' '#[fg=#e0af68]'
        ;;
    esac
}

opencode_status() {
    local line=""
    line="$(tmux show-environment -g OPENCODE_STATUS 2>/dev/null || true)"
    case "$line" in
    OPENCODE_STATUS=*) printf '%s\n' "${line#OPENCODE_STATUS=}" ;;
    *) printf '%s\n' active ;;
    esac
}

set_window_style() {
    [ -n "$STYLE_TARGET" ] || return 0
    tmux set-window-option -t "$STYLE_TARGET" @wname_style "$(status_style "$1")" >/dev/null 2>&1 || true
}

sync_window_style() {
    local status=""
    local last_status=""

    while :; do
        status="$(opencode_status)"
        if [ "$status" != "$last_status" ]; then
            set_window_style "$status"
            last_status="$status"
        fi
        sleep 0.5
    done
}

restore_alternate_screen() {
    if [ -n "$WINDOW" ]; then
        tmux setw -t "$WINDOW" alternate-screen on >/dev/null 2>&1 || true
    else
        tmux setw -w alternate-screen on >/dev/null 2>&1 || true
    fi
}

cleanup() {
    if [ -n "$SYNC_PID" ]; then
        kill "$SYNC_PID" >/dev/null 2>&1 || true
    fi
    if [ -n "$STYLE_TARGET" ]; then
        tmux set-window-option -t "$STYLE_TARGET" -u @wname_style >/dev/null 2>&1 || true
    fi
    restore_alternate_screen
}

trap cleanup EXIT

if [ -n "$WINDOW" ]; then
    tmux setw -t "$WINDOW" alternate-screen off >/dev/null 2>&1 || true
else
    tmux setw -w alternate-screen off >/dev/null 2>&1 || true
fi

if [ -n "$STYLE_TARGET" ]; then
    set_window_style active
    sync_window_style &
    SYNC_PID="$!"
fi

status=0
OPENCODE_DIR="$PWD" "$HOME/dotfiles/scripts/bin/oc" "$@" || status="$?"
exit "$status"
