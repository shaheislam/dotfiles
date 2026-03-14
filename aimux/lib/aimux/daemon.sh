#!/usr/bin/env bash
# aimux daemon - agent state monitoring daemon

DAEMON_PID_FILE="/tmp/aimux-daemon.pid"
POLL_INTERVAL="${AIMUX_POLL_INTERVAL:-10}"

_daemon_start() {
    if [[ -f "$DAEMON_PID_FILE" ]] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
        info "Daemon already running (PID: $(cat "$DAEMON_PID_FILE"))"
        return 0
    fi

    require tmux

    info "Starting aimux daemon (poll every ${POLL_INTERVAL}s)"

    (
        trap 'rm -f "$DAEMON_PID_FILE"; exit 0' EXIT INT TERM
        echo $$ >"$DAEMON_PID_FILE"

        while true; do
            _daemon_poll 2>/dev/null || true
            sleep "$POLL_INTERVAL"
        done
    ) &

    disown
    local pid=$!
    echo "$pid" >"$DAEMON_PID_FILE"
    info "Daemon started (PID: $pid)"
    log "daemon: started PID $pid"
}

_daemon_stop() {
    if [[ -f "$DAEMON_PID_FILE" ]]; then
        local pid
        pid=$(cat "$DAEMON_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            rm -f "$DAEMON_PID_FILE"
            info "Daemon stopped (PID: $pid)"
            log "daemon: stopped PID $pid"
        else
            rm -f "$DAEMON_PID_FILE"
            info "Stale PID file removed"
        fi
    else
        info "Daemon not running"
    fi
}

_daemon_status() {
    if [[ -f "$DAEMON_PID_FILE" ]] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
        printf "${GREEN}running${RESET} (PID: %s)\n" "$(cat "$DAEMON_PID_FILE")"
    else
        printf "${DIM}stopped${RESET}\n"
        [[ -f "$DAEMON_PID_FILE" ]] && rm -f "$DAEMON_PID_FILE" || true
    fi
}

_daemon_poll() {
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_tty} #{window_name}' 2>/dev/null |
        while IFS=' ' read -r target tty wname; do
            [[ -z "$tty" ]] && continue

            # Check for agent process on TTY
            local has_agent=false
            if ps -t "$tty" -o comm= 2>/dev/null | grep -qE '(claude|codex|opencode)'; then
                has_agent=true
            fi

            local win="${target%.*}"

            if $has_agent; then
                # Capture last 20 lines
                local content
                content=$(tmux capture-pane -t "$target" -p -S -20 2>/dev/null || echo "")

                local state="idle"
                if echo "$content" | grep -qE '… \(' 2>/dev/null; then
                    state="working"
                elif echo "$content" | grep -qE 'COMPLETE|_DONE|TICKET_TASK_COMPLETE' 2>/dev/null; then
                    state="done"
                fi

                # Set tmux window color
                local color=""
                case "$state" in
                working) color="$COLOR_WORKING" ;;
                idle) color="$COLOR_WAITING" ;;
                done) color="$COLOR_DONE" ;;
                esac

                [[ -n "$color" ]] && tmux set-window-option -t "$win" @wname_style "fg=$color" 2>/dev/null || true

                # Notify on completion (deduplicated)
                if [[ "$state" == "done" ]]; then
                    local nf="/tmp/aimux-notified-${target//[:.\/]/-}"
                    if [[ ! -f "$nf" ]]; then
                        touch "$nf"
                        # Inline notification (avoid re-sourcing notify.sh in daemon loop)
                        if [[ "$(uname)" == "Darwin" ]]; then
                            osascript -e "display notification \"Agent complete: $wname\" with title \"aimux\"" 2>/dev/null || true
                        elif has notify-send; then
                            notify-send "aimux" "Agent complete: $wname" 2>/dev/null || true
                        fi
                        printf '\a' # terminal bell
                    fi
                fi
            else
                # No agent — clear color
                tmux set-window-option -t "$win" -u @wname_style 2>/dev/null || true
                rm -f "/tmp/aimux-notified-${target//[:.\/]/-}" 2>/dev/null || true
            fi
        done
}

# Dispatch
case "${1:-status}" in
start) _daemon_start ;;
stop) _daemon_stop ;;
status) _daemon_status ;;
poll) _daemon_poll ;;
-h | --help)
    echo "Usage: aimux daemon [start|stop|status|poll]"
    exit 0
    ;;
*) die "Unknown daemon command: $1" ;;
esac
