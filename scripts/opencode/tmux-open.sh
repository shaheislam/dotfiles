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
    idle | active)
        printf '%s\n' '#[fg=#e0af68]'
        ;;
    *)
        printf '%s\n' '#[fg=#e0af68]'
        ;;
    esac
}

opencode_status() {
    local pane_text=""

    if [ -n "$WINDOW" ]; then
        pane_text="$(tmux capture-pane -t "$WINDOW" -S -30 -p 2>/dev/null || true)"
        if printf '%s\n' "$pane_text" | grep -q 'esc interrupt'; then
            printf '%s\n' busy
            return 0
        fi
        if printf '%s\n' "$pane_text" | grep -q 'ctrl[+]p commands'; then
            printf '%s\n' idle
            return 0
        fi
    fi

    printf '%s\n' idle
}

set_window_style() {
    [ -n "$STYLE_TARGET" ] || return 0
    tmux set-window-option -t "$STYLE_TARGET" @wname_style "$(status_style "$1")" >/dev/null 2>&1 || true
}

clear_pane_style() {
    [ -n "$WINDOW" ] || return 0
    tmux set-option -p -u -t "$WINDOW" @wname_style >/dev/null 2>&1 || true
}

sync_window_style() {
    local status=""

    while :; do
        status="$(opencode_status)"
        # Reassert every poll. Other tmux hooks/reloads can clear @wname_style
        # without changing the window status, so change-only updates are brittle.
        set_window_style "$status"
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
    clear_pane_style
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
    clear_pane_style
    set_window_style "$(opencode_status)"
    sync_window_style &
    SYNC_PID="$!"
fi

status=0
OPENCODE_DIR="$PWD" "$HOME/dotfiles/scripts/bin/oc" "$@" || status="$?"
exit "$status"
