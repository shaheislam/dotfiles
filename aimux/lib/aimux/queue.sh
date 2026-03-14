#!/usr/bin/env bash
# aimux queue - ticket queue management

AIMUX_QUEUE_FILE="$AIMUX_HOME/queue.json"
AIMUX_QUEUE_PID_FILE="/tmp/aimux-queue.pid"

_queue_ensure() {
    ensure_home
    if [[ ! -f "$AIMUX_QUEUE_FILE" ]]; then
        echo "[]" >"$AIMUX_QUEUE_FILE"
    fi
}

_queue_read() {
    _queue_ensure
    cat "$AIMUX_QUEUE_FILE"
}

_queue_write() {
    local content="$1"
    local tmp="${AIMUX_QUEUE_FILE}.tmp"
    echo "$content" >"$tmp"
    mv "$tmp" "$AIMUX_QUEUE_FILE"
}

_queue_count() {
    local status="${1:-}"
    if has jq; then
        if [[ -n "$status" ]]; then
            _queue_read | jq "[.[] | select(.status == \"$status\")] | length" 2>/dev/null || echo "0"
        else
            _queue_read | jq 'length' 2>/dev/null || echo "0"
        fi
    else
        echo "0"
    fi
}

_queue_add() {
    local ticket="" prompt="" provider="" priority=5

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --provider | -P)
            provider="$2"
            shift 2
            ;;
        --priority | -p)
            priority="$2"
            shift 2
            ;;
        -h | --help)
            echo "Usage: aimux queue add [--provider NAME] [--priority N] <ticket> [prompt...]"
            exit 0
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            if [[ -z "$ticket" ]]; then
                ticket="$1"
            else
                prompt="${prompt:+$prompt }$1"
            fi
            shift
            ;;
        esac
    done

    [[ -z "$ticket" ]] && die "Usage: aimux queue add <ticket> [prompt]"
    [[ -z "$provider" ]] && provider="$(cfg_get "general.default_provider" "claude")"

    require jq

    _queue_ensure
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    local entry
    entry="$(jq -n \
        --arg ticket "$ticket" \
        --arg prompt "$prompt" \
        --arg provider "$provider" \
        --argjson priority "$priority" \
        --arg status "queued" \
        --arg added_at "$now" \
        '{ticket: $ticket, prompt: $prompt, provider: $provider, priority: $priority, status: $status, added_at: $added_at, started_at: null, completed_at: null}')"

    local queue
    queue="$(_queue_read)"
    queue="$(echo "$queue" | jq ". + [$entry]")"
    _queue_write "$queue"

    info "Queued: $ticket (provider: $provider, priority: $priority)"
    log "queue: added $ticket (provider: $provider, priority: $priority)"
}

_queue_list() {
    require jq
    _queue_ensure

    local queue
    queue="$(_queue_read)"
    local count
    count="$(echo "$queue" | jq 'length')"

    if [[ "$count" -eq 0 ]]; then
        info "Queue is empty"
        return 0
    fi

    printf "${BOLD}%-15s %-12s %-10s %-8s %-20s %-30s${RESET}\n" \
        "TICKET" "PROVIDER" "STATUS" "PRI" "ADDED" "PROMPT"
    printf "%-15s %-12s %-10s %-8s %-20s %-30s\n" \
        "$(printf '%0.s─' {1..15})" \
        "$(printf '%0.s─' {1..12})" \
        "$(printf '%0.s─' {1..10})" \
        "$(printf '%0.s─' {1..8})" \
        "$(printf '%0.s─' {1..20})" \
        "$(printf '%0.s─' {1..30})"

    echo "$queue" | jq -r 'sort_by(-.priority) | .[] | [.ticket, .provider, .status, (.priority|tostring), .added_at, .prompt] | @tsv' |
        while IFS=$'\t' read -r ticket provider status pri added prompt; do
            # Colorize status
            case "$status" in
            queued) status_c="${CYAN}queued${RESET}" ;;
            dispatching) status_c="${YELLOW}dispatch${RESET}" ;;
            running) status_c="${RED}running${RESET}" ;;
            completed) status_c="${GREEN}done${RESET}" ;;
            failed) status_c="${RED}failed${RESET}" ;;
            *) status_c="$status" ;;
            esac

            # Truncate prompt
            [[ ${#prompt} -gt 28 ]] && prompt="${prompt:0:25}..."

            printf "%-15s %-12s %-10b %-8s %-20s %-30s\n" \
                "$ticket" "$provider" "$status_c" "$pri" "$added" "$prompt"
        done
}

_queue_remove() {
    local ticket="$1"
    [[ -z "$ticket" ]] && die "Usage: aimux queue remove <ticket>"
    require jq

    _queue_ensure
    local queue before after
    queue="$(_queue_read)"
    before="$(echo "$queue" | jq 'length')"
    queue="$(echo "$queue" | jq "[.[] | select(.ticket != \"$ticket\")]")"
    after="$(echo "$queue" | jq 'length')"
    _queue_write "$queue"

    local removed=$((before - after))
    if [[ "$removed" -gt 0 ]]; then
        info "Removed $removed entries for: $ticket"
    else
        warn "No entries found for: $ticket"
    fi
}

_queue_clear() {
    require jq
    _queue_ensure

    local queue
    queue="$(_queue_read)"
    queue="$(echo "$queue" | jq '[.[] | select(.status == "queued" or .status == "dispatching")]')"
    _queue_write "$queue"
    info "Cleared completed/failed entries"
}

_queue_dispatcher_running() {
    [[ -f "$AIMUX_QUEUE_PID_FILE" ]] && kill -0 "$(cat "$AIMUX_QUEUE_PID_FILE")" 2>/dev/null
}

_queue_start() {
    if _queue_dispatcher_running; then
        info "Queue dispatcher already running (PID: $(cat "$AIMUX_QUEUE_PID_FILE"))"
        return 0
    fi

    require jq
    require tmux

    local max_concurrent cooldown
    max_concurrent="$(cfg_get "queue.max_concurrent" "3")"
    cooldown="$(cfg_get "queue.cooldown" "60")"

    info "Starting queue dispatcher (max: $max_concurrent, cooldown: ${cooldown}s)"

    (
        trap 'rm -f "'"$AIMUX_QUEUE_PID_FILE"'"; exit 0' EXIT INT TERM
        echo $$ >"$AIMUX_QUEUE_PID_FILE"

        while true; do
            _queue_ensure

            # Count currently running
            local running
            running="$(_queue_count "running")"

            if [[ "$running" -lt "$max_concurrent" ]]; then
                # Dequeue highest priority "queued" entry
                local queue
                queue="$(_queue_read)"
                local next
                next="$(echo "$queue" | jq -r '[.[] | select(.status == "queued")] | sort_by(-.priority) | .[0] // empty')"

                if [[ -n "$next" && "$next" != "null" ]]; then
                    local ticket prompt provider
                    ticket="$(echo "$next" | jq -r '.ticket')"
                    prompt="$(echo "$next" | jq -r '.prompt // ""')"
                    provider="$(echo "$next" | jq -r '.provider // "claude"')"

                    # Mark as dispatching
                    local now
                    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                    queue="$(echo "$queue" | jq "(.[] | select(.ticket == \"$ticket\" and .status == \"queued\") | .status) = \"dispatching\" | (.[] | select(.ticket == \"$ticket\" and .status == \"dispatching\") | .started_at) = \"$now\"")"
                    _queue_write "$queue"

                    log "queue: dispatching $ticket via $provider"

                    # Launch via aimux run (in background)
                    local run_args=("$ticket")
                    [[ -n "$prompt" ]] && run_args+=("$prompt")
                    run_args+=(--provider "$provider")

                    if "$AIMUX_DIR/bin/aimux" run "${run_args[@]}" 2>>"$AIMUX_LOG"; then
                        # Mark as running
                        queue="$(_queue_read)"
                        queue="$(echo "$queue" | jq "(.[] | select(.ticket == \"$ticket\" and .status == \"dispatching\") | .status) = \"running\"")"
                        _queue_write "$queue"
                        log "queue: $ticket now running"
                    else
                        # Mark as failed
                        queue="$(_queue_read)"
                        now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                        queue="$(echo "$queue" | jq "(.[] | select(.ticket == \"$ticket\" and .status == \"dispatching\") | .status) = \"failed\" | (.[] | select(.ticket == \"$ticket\" and .status == \"failed\") | .completed_at) = \"$now\"")"
                        _queue_write "$queue"
                        log "queue: $ticket failed to dispatch"
                    fi
                fi
            fi

            # Check for completed runs (via state files)
            queue="$(_queue_read)"
            echo "$queue" | jq -r '.[] | select(.status == "running") | .ticket' | while IFS= read -r ticket; do
                [[ -z "$ticket" ]] && continue
                local branch_name
                branch_name="$(echo "$ticket" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"

                # Find state file by looking for matching ticket
                for sf in "$AIMUX_STATE_DIR"/*.json; do
                    [[ -f "$sf" ]] || continue
                    local ws_name
                    ws_name="$(basename "$sf" .json)"
                    local ws_ticket ws_status
                    ws_ticket="$(state_read "$ws_name" "ticket" "")"
                    ws_status="$(state_read "$ws_name" "status" "")"

                    if [[ "$ws_ticket" == "$ticket" ]]; then
                        case "$ws_status" in
                        completed | done)
                            local now_ts
                            now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                            queue="$(_queue_read)"
                            queue="$(echo "$queue" | jq "(.[] | select(.ticket == \"$ticket\" and .status == \"running\") | .status) = \"completed\" | (.[] | select(.ticket == \"$ticket\" and .status == \"completed\") | .completed_at) = \"$now_ts\"")"
                            _queue_write "$queue"
                            log "queue: $ticket completed"
                            ;;
                        failed)
                            local now_ts
                            now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                            queue="$(_queue_read)"
                            queue="$(echo "$queue" | jq "(.[] | select(.ticket == \"$ticket\" and .status == \"running\") | .status) = \"failed\" | (.[] | select(.ticket == \"$ticket\" and .status == \"failed\") | .completed_at) = \"$now_ts\"")"
                            _queue_write "$queue"
                            log "queue: $ticket failed"
                            ;;
                        esac
                        break
                    fi
                done
            done

            sleep "$cooldown"
        done
    ) &

    disown
    local pid=$!
    echo "$pid" >"$AIMUX_QUEUE_PID_FILE"
    info "Queue dispatcher started (PID: $pid)"
    log "queue: dispatcher started PID $pid"
}

_queue_stop() {
    if [[ -f "$AIMUX_QUEUE_PID_FILE" ]]; then
        local pid
        pid="$(cat "$AIMUX_QUEUE_PID_FILE")"
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            rm -f "$AIMUX_QUEUE_PID_FILE"
            info "Queue dispatcher stopped (PID: $pid)"
            log "queue: dispatcher stopped PID $pid"
        else
            rm -f "$AIMUX_QUEUE_PID_FILE"
            info "Stale PID file removed"
        fi
    else
        info "Queue dispatcher not running"
    fi
}

_queue_status() {
    _queue_ensure

    printf "${BOLD}Queue Status${RESET}\n"

    # Dispatcher
    if _queue_dispatcher_running; then
        printf "  Dispatcher: ${GREEN}running${RESET} (PID: %s)\n" "$(cat "$AIMUX_QUEUE_PID_FILE")"
    else
        printf "  Dispatcher: ${DIM}stopped${RESET}\n"
    fi

    if has jq; then
        local queued running completed failed total
        queued="$(_queue_count "queued")"
        running="$(_queue_count "running")"
        completed="$(_queue_count "completed")"
        failed="$(_queue_count "failed")"
        total="$(_queue_count)"

        printf "  Total:      %s\n" "$total"
        printf "  Queued:     %s\n" "$queued"
        printf "  Running:    %s\n" "$running"
        printf "  Completed:  %s\n" "$completed"
        printf "  Failed:     %s\n" "$failed"
        printf "  Max conc:   %s\n" "$(cfg_get "queue.max_concurrent" "3")"
        printf "  Cooldown:   %ss\n" "$(cfg_get "queue.cooldown" "60")"
    else
        warn "jq required for queue stats"
    fi
}

# Dispatch
case "${1:-help}" in
add)
    shift
    _queue_add "$@"
    ;;
list | ls)
    _queue_list
    ;;
start)
    _queue_start
    ;;
stop)
    _queue_stop
    ;;
status)
    _queue_status
    ;;
remove | rm)
    shift
    _queue_remove "${1:-}"
    ;;
clear)
    _queue_clear
    ;;
-h | --help | help | *)
    cat <<'HELP'
Usage: aimux queue <subcommand>

Manage ticket execution queue

Subcommands:
  add <ticket> [prompt]   Add ticket to queue
    --provider NAME       AI provider (default: from config)
    --priority N          Priority 1-10, higher = first (default: 5)
  list                    Show queued tickets
  start                   Start queue dispatcher (background)
  stop                    Stop queue dispatcher
  status                  Show dispatcher status + queue stats
  remove <ticket>         Remove ticket from queue
  clear                   Clear completed/failed entries
  help                    Show this help

Examples:
  aimux queue add PROJ-123 "Fix the auth bug"
  aimux queue add TASK-456 --provider codex --priority 8 "Add tests"
  aimux queue start
  aimux queue list
  aimux queue status
HELP
    ;;
esac
