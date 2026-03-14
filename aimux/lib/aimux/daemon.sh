#!/usr/bin/env bash
# aimux daemon - agent state monitoring daemon with provider detection

DAEMON_PID_FILE="/tmp/aimux-daemon.pid"
POLL_INTERVAL="${AIMUX_POLL_INTERVAL:-10}"
STUCK_TIMEOUT="${AIMUX_STUCK_TIMEOUT:-300}"

# Track last content hash per pane for stuck detection
declare -gA _DAEMON_CONTENT_HASH=()
declare -gA _DAEMON_LAST_CHANGE=()

_daemon_start() {
    if [[ -f "$DAEMON_PID_FILE" ]] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
        info "Daemon already running (PID: $(cat "$DAEMON_PID_FILE"))"
        return 0
    fi

    require tmux

    info "Starting aimux daemon (poll every ${POLL_INTERVAL}s, stuck after ${STUCK_TIMEOUT}s)"

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

_daemon_detect_provider() {
    # Given a tty, detect which provider is running on it
    local tty="$1"
    local prov
    for prov in $(provider_list 2>/dev/null); do
        if provider_detect "$prov" "$tty" 2>/dev/null; then
            echo "$prov"
            return 0
        fi
    done
    # Fallback: direct process scan
    local procs
    procs="$(ps -t "$tty" -o comm= 2>/dev/null || echo "")"
    if echo "$procs" | grep -qE 'claude'; then
        echo "claude"
        return 0
    elif echo "$procs" | grep -qE 'codex'; then
        echo "codex"
        return 0
    elif echo "$procs" | grep -qE 'ollama'; then
        echo "ollama"
        return 0
    fi
    return 1
}

_daemon_poll() {
    local now
    now="$(date +%s)"

    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_tty} #{window_name}' 2>/dev/null |
        while IFS=' ' read -r target tty wname; do
            [[ -z "$tty" ]] && continue

            local win="${target%.*}"

            # Detect provider on this tty
            local prov=""
            prov="$(_daemon_detect_provider "$tty" 2>/dev/null || echo "")"

            if [[ -n "$prov" ]]; then
                # Capture last 20 lines
                local content
                content=$(tmux capture-pane -t "$target" -p -S -20 2>/dev/null || echo "")

                # Content hash for stuck detection
                local content_hash
                content_hash="$(echo "$content" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$RANDOM")"

                local pane_key="${target//[:.\/]/-}"

                if [[ "${_DAEMON_CONTENT_HASH[$pane_key]:-}" != "$content_hash" ]]; then
                    _DAEMON_CONTENT_HASH["$pane_key"]="$content_hash"
                    _DAEMON_LAST_CHANGE["$pane_key"]="$now"
                fi

                # Detect state via provider
                local state="idle"
                if provider_load "$prov" 2>/dev/null; then
                    state="$(provider_detect_state "$prov" "$content" 2>/dev/null || echo "idle")"
                fi

                # Stuck detection
                local last_change="${_DAEMON_LAST_CHANGE[$pane_key]:-$now}"
                local idle_secs=$((now - last_change))
                if [[ "$idle_secs" -ge "$STUCK_TIMEOUT" && "$state" != "done" ]]; then
                    state="stuck"
                fi

                # Set tmux window color
                local color=""
                case "$state" in
                working) color="$COLOR_WORKING" ;;
                idle) color="$COLOR_WAITING" ;;
                done) color="$COLOR_DONE" ;;
                stuck) color="$COLOR_STUCK" ;;
                esac

                [[ -n "$color" ]] && tmux set-window-option -t "$win" @wname_style "fg=$color" 2>/dev/null || true

                # Notify on completion (deduplicated)
                if [[ "$state" == "done" ]]; then
                    local nf="/tmp/aimux-notified-${pane_key}"
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

                # Notify on stuck (deduplicated)
                if [[ "$state" == "stuck" ]]; then
                    local sf="/tmp/aimux-stuck-${pane_key}"
                    if [[ ! -f "$sf" ]]; then
                        touch "$sf"
                        if [[ "$(uname)" == "Darwin" ]]; then
                            osascript -e "display notification \"Agent stuck: $wname (${idle_secs}s idle)\" with title \"aimux\"" 2>/dev/null || true
                        elif has notify-send; then
                            notify-send "aimux" "Agent stuck: $wname (${idle_secs}s idle)" 2>/dev/null || true
                        fi
                        printf '\a'
                    fi
                fi
            else
                # No agent — clear color and tracking
                tmux set-window-option -t "$win" -u @wname_style 2>/dev/null || true
                local pane_key="${target//[:.\/]/-}"
                rm -f "/tmp/aimux-notified-${pane_key}" 2>/dev/null || true
                rm -f "/tmp/aimux-stuck-${pane_key}" 2>/dev/null || true
                unset "_DAEMON_CONTENT_HASH[$pane_key]" 2>/dev/null || true
                unset "_DAEMON_LAST_CHANGE[$pane_key]" 2>/dev/null || true
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
    cat <<'HELP'
Usage: aimux daemon [start|stop|status|poll]

Agent state monitoring daemon — polls tmux panes for AI agent activity

Commands:
  start    Start the background daemon
  stop     Stop the daemon
  status   Show daemon status
  poll     Run one poll cycle (for debugging)

The daemon uses the provider plugin system to detect agent processes
and their state (working/idle/done/stuck). It sets tmux window colors
accordingly and sends notifications on completion or stuck detection.
HELP
    exit 0
    ;;
*) die "Unknown daemon command: $1" ;;
esac
