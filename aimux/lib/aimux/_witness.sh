#!/usr/bin/env bash
# aimux witness — per-workspace lifecycle monitor

_witness_pid_file() {
    local workspace="$1"
    echo "$AIMUX_HOME/state/${workspace}.witness.pid"
}

_witness_is_running() {
    local workspace="$1"
    local pf
    pf="$(_witness_pid_file "$workspace")"
    [[ -f "$pf" ]] && kill -0 "$(cat "$pf")" 2>/dev/null
}

witness_start() {
    local workspace="$1"
    local state_file="$2"
    local max_retries="${3:-3}"

    if _witness_is_running "$workspace"; then
        info "Witness already running for $workspace"
        return 0
    fi

    local pf
    pf="$(_witness_pid_file "$workspace")"
    mkdir -p "$(dirname "$pf")"

    local poll_interval
    poll_interval="$(cfg_get "general.poll_interval" "10")"
    local stuck_timeout
    stuck_timeout="$(cfg_get "general.stuck_timeout" "300")"

    # Resolve provider and tmux target from state file
    local provider tmux_target wt_dir
    provider="$(state_read "$workspace" "provider" "claude")"
    tmux_target="$(state_read "$workspace" "tmux_target" "")"
    wt_dir="$(state_read "$workspace" "worktree" "")"

    if [[ -z "$tmux_target" ]]; then
        warn "No tmux target in state for $workspace, witness cannot monitor"
        return 1
    fi

    # Launch witness as background process
    (
        trap 'rm -f "'"$pf"'"; exit 0' EXIT INT TERM
        echo $$ >"$pf"

        local attempts=0
        local last_content_hash=""
        local last_content_change
        last_content_change="$(date +%s)"

        while true; do
            sleep "$poll_interval"

            # Check if tmux pane still exists
            if ! tmux has-session -t "${tmux_target%%.*}" 2>/dev/null; then
                log "witness($workspace): tmux session gone, exiting"
                state_write "$workspace" \
                    status=completed \
                    ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    exit_reason="session_gone"
                break
            fi

            # Capture pane content
            local content
            content="$(tmux capture-pane -t "$tmux_target" -p -S -30 2>/dev/null || echo "")"

            if [[ -z "$content" ]]; then
                continue
            fi

            # Check for content change (stuck detection)
            local content_hash
            content_hash="$(echo "$content" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$content")"
            if [[ "$content_hash" != "$last_content_hash" ]]; then
                last_content_hash="$content_hash"
                last_content_change="$(date +%s)"
            fi

            # Detect state via provider
            local detected_state="idle"
            if provider_load "$provider" 2>/dev/null; then
                detected_state="$(provider_detect_state "$provider" "$content")"
            fi

            local now
            now="$(date +%s)"
            local idle_secs=$((now - last_content_change))

            # Stuck detection
            if [[ "$idle_secs" -ge "$stuck_timeout" && "$detected_state" != "done" ]]; then
                detected_state="stuck"
            fi

            # Update state file
            state_write "$workspace" \
                status="$detected_state" \
                provider="$provider" \
                tmux_target="$tmux_target" \
                worktree="$wt_dir" \
                attempts="$attempts" \
                idle_seconds="$idle_secs" \
                last_poll="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

            case "$detected_state" in
            done)
                log "witness($workspace): agent completed"
                state_write "$workspace" \
                    status=completed \
                    provider="$provider" \
                    tmux_target="$tmux_target" \
                    worktree="$wt_dir" \
                    attempts="$attempts" \
                    ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    exit_reason="completed"
                # Send notification
                if [[ -f "$AIMUX_LIB/notify.sh" ]]; then
                    (source "$AIMUX_LIB/notify.sh" "Agent completed: $workspace" --all) 2>/dev/null || true
                fi
                break
                ;;
            stuck)
                log "witness($workspace): agent stuck (${idle_secs}s idle)"
                attempts=$((attempts + 1))

                if [[ "$attempts" -ge "$max_retries" ]]; then
                    log "witness($workspace): max retries ($max_retries) reached"
                    state_write "$workspace" \
                        status=failed \
                        provider="$provider" \
                        tmux_target="$tmux_target" \
                        worktree="$wt_dir" \
                        attempts="$attempts" \
                        ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        exit_reason="max_retries"
                    if [[ -f "$AIMUX_LIB/notify.sh" ]]; then
                        (source "$AIMUX_LIB/notify.sh" "Agent failed (stuck): $workspace" --all) 2>/dev/null || true
                    fi
                    break
                fi

                # Attempt restart: send Ctrl-C then re-launch
                log "witness($workspace): attempting restart ($attempts/$max_retries)"
                tmux send-keys -t "$tmux_target" C-c 2>/dev/null || true
                sleep 2

                # Re-launch if launch script exists
                local launch_script="$wt_dir/.aimux/launch.sh"
                if [[ -f "$launch_script" ]]; then
                    tmux send-keys -t "$tmux_target" "bash $launch_script" Enter 2>/dev/null || true
                fi

                last_content_hash=""
                last_content_change="$(date +%s)"
                ;;
            esac
        done
    ) &

    disown
    local bg_pid=$!
    echo "$bg_pid" >"$pf"
    log "witness: started for $workspace (PID: $bg_pid)"
    info "Witness started for $workspace (PID: $bg_pid)"
}

witness_stop() {
    local workspace="$1"
    local pf
    pf="$(_witness_pid_file "$workspace")"

    if [[ -f "$pf" ]]; then
        local pid
        pid="$(cat "$pf")"
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            info "Witness stopped for $workspace (PID: $pid)"
            log "witness: stopped for $workspace (PID: $pid)"
        else
            info "Witness was not running for $workspace (stale PID)"
        fi
        rm -f "$pf"
    else
        info "No witness running for $workspace"
    fi
}

witness_status() {
    local workspace="$1"
    local pf
    pf="$(_witness_pid_file "$workspace")"

    if _witness_is_running "$workspace"; then
        local pid
        pid="$(cat "$pf")"
        local attempts idle
        attempts="$(state_read "$workspace" "attempts" "0")"
        idle="$(state_read "$workspace" "idle_seconds" "0")"
        printf "${GREEN}running${RESET} (PID: %s, attempts: %s, idle: %ss)\n" "$pid" "$attempts" "$idle"
    else
        [[ -f "$pf" ]] && rm -f "$pf"
        printf "${DIM}stopped${RESET}\n"
    fi
}
