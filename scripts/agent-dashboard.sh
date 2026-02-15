#!/usr/bin/env bash
# agent-dashboard.sh - Dashboard launcher for agent monitoring
#
# Usage:
#     agent-dashboard.sh start [--port 8787]
#     agent-dashboard.sh stop
#     agent-dashboard.sh open
#     agent-dashboard.sh status

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${HOME}/.claude/dashboard.pid"
DEFAULT_PORT=8787

cmd_start() {
    local port="$DEFAULT_PORT"
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --port)
            port="$2"
            shift 2
            ;;
        *)
            shift
            ;;
        esac
    done

    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Dashboard already running (PID $pid)"
            return 0
        fi
        rm -f "$PID_FILE"
    fi

    python3 "${SCRIPT_DIR}/agent-dashboard-server.py" --port "$port" &
    local pid=$!
    echo "$pid" >"$PID_FILE"
    echo "Dashboard started on http://127.0.0.1:${port} (PID $pid)"
}

cmd_stop() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "Dashboard not running"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "Dashboard stopped (PID $pid)"
    else
        echo "Dashboard was not running (stale PID)"
    fi
    rm -f "$PID_FILE"
}

cmd_open() {
    local port="$DEFAULT_PORT"
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "Dashboard not running, starting..."
            cmd_start "$@"
        fi
    else
        echo "Dashboard not running, starting..."
        cmd_start "$@"
    fi
    open "http://127.0.0.1:${port}"
}

cmd_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "running (PID $pid)"
            return 0
        fi
        rm -f "$PID_FILE"
    fi
    echo "stopped"
    return 1
}

cmd_usage() {
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start [--port N]  Start dashboard server (default: $DEFAULT_PORT)"
    echo "  stop              Stop dashboard server"
    echo "  open              Open dashboard in browser (starts if needed)"
    echo "  status            Show dashboard status"
}

case "${1:-}" in
start)
    shift
    cmd_start "$@"
    ;;
stop)
    cmd_stop
    ;;
open)
    shift
    cmd_open "$@"
    ;;
status)
    cmd_status
    ;;
-h | --help | "")
    cmd_usage
    ;;
*)
    echo "Unknown command: $1"
    cmd_usage
    exit 1
    ;;
esac
