#!/usr/bin/env bash
# Launch OpenCode inside tmux with alternate-screen disabled so tmux copy-mode
# retains scrollback. Restores the prior setting when OpenCode exits.
set -euo pipefail

# Determine current pane/window so local tmux state follows this OpenCode UI.
WINDOW=${TMUX_PANE:-}
STYLE_TARGET=""
ATTACH_FILE=""
UNREGISTER_ATTACH=1
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
ATTACH_DIR="$STATE_HOME/opencode/attaches"

if [ -n "${TMUX:-}" ]; then
    STYLE_TARGET="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
    export TMUX_AGENT_TARGET="$STYLE_TARGET"
fi

if [ -z "$STYLE_TARGET" ]; then
    STYLE_TARGET="$WINDOW"
fi

clear_pane_style() {
    [ -n "$WINDOW" ] || return 0
    tmux set-option -p -u -t "$WINDOW" @wname_style >/dev/null 2>&1 || true
}

restore_alternate_screen() {
    if [ -n "$WINDOW" ]; then
        tmux setw -t "$WINDOW" alternate-screen on >/dev/null 2>&1 || true
    else
        tmux setw -w alternate-screen on >/dev/null 2>&1 || true
    fi
}

pane_key() {
    local pane_id="$1"
    pane_id="${pane_id#%}"
    printf 'pane-%s' "$(printf '%s' "$pane_id" | tr -c '[:alnum:]_.-' '_')"
}

register_attach() {
    [ -n "$WINDOW" ] || return 0
    [ -n "${1:-}" ] || return 0

    local attach_pid="$1"
    shift

    mkdir -p "$ATTACH_DIR"
    if [ -z "$ATTACH_FILE" ]; then
        ATTACH_FILE="$ATTACH_DIR/$(pane_key "$WINDOW").pid"
    fi
    {
        printf 'pid=%s\n' "$attach_pid"
        printf 'pane=%s\n' "$WINDOW"
        printf 'cwd=%s\n' "$PWD"
        printf 'started=%s\n' "$(date +%s)"
        printf 'command=%s\n' "$HOME/dotfiles/scripts/bin/oc $*"
    } >"$ATTACH_FILE"
}

unregister_attach() {
    [ "$UNREGISTER_ATTACH" = "1" ] || return 0
    [ -n "$ATTACH_FILE" ] || return 0
    rm -f "$ATTACH_FILE" >/dev/null 2>&1 || true
}

cleanup() {
    unregister_attach
    clear_pane_style
    if [ -n "$STYLE_TARGET" ]; then
        tmux set-window-option -t "$STYLE_TARGET" -u @wname_style >/dev/null 2>&1 || true
    fi
    restore_alternate_screen
}

trap cleanup EXIT
trap 'UNREGISTER_ATTACH=0; status=129; cleanup; trap - EXIT; exit "$status"' HUP
trap 'status=130; cleanup; trap - EXIT; exit "$status"' INT
trap 'UNREGISTER_ATTACH=0; status=143; cleanup; trap - EXIT; exit "$status"' TERM

if [ -n "$WINDOW" ]; then
    tmux setw -t "$WINDOW" alternate-screen off >/dev/null 2>&1 || true
else
    tmux setw -w alternate-screen off >/dev/null 2>&1 || true
fi

clear_pane_style

export OPENCODE_TMUX_WRAPPER_ACTIVE=1

if [ -n "$WINDOW" ]; then
    mkdir -p "$ATTACH_DIR"
    ATTACH_FILE="$ATTACH_DIR/$(pane_key "$WINDOW").pid"
fi

status=0
(
    register_attach "$BASHPID" "$@"
    OPENCODE_DIR="$PWD" exec "$HOME/dotfiles/scripts/bin/oc" "$@"
) || status="$?"
exit "$status"
