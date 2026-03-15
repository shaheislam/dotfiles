#!/usr/bin/env bash
# aimux provider: Claude Code

provider_claude_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd
    cmd="$(cfg_get "providers.claude.command" "claude")"
    local args_raw
    args_raw="$(cfg_get "providers.claude.args" '["--effort", "max"]')"
    # Parse args array to flat string
    local args
    args="$(echo "$args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
    [[ -z "$args" ]] && args="--effort max"

    if [[ -n "$prompt" ]]; then
        echo "$cmd $args -p \"$prompt\""
    else
        echo "$cmd $args"
    fi
}

provider_claude_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'claude'
}

provider_claude_detect_state() {
    local content="$1"

    # Check error/failure patterns first (highest priority)
    if echo "$content" | grep -qE 'Session expired|API error|rate limit|Error:' 2>/dev/null; then
        echo "failed"
        return 0
    fi

    # Check done patterns
    local done_raw
    done_raw="$(cfg_get "providers.claude.done_patterns" '["COMPLETE", "_DONE", "TICKET_TASK_COMPLETE"]')"
    local pattern
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        if echo "$content" | grep -qF "$pattern" 2>/dev/null; then
            echo "done"
            return 0
        fi
    done < <(echo "$done_raw" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Check working pattern (spinner / active processing)
    local working
    working="$(cfg_get "providers.claude.working_pattern" '… \(')"
    if [[ -n "$working" ]] && echo "$content" | grep -qE "$working" 2>/dev/null; then
        echo "working"
        return 0
    fi

    # Detect Claude asking for input — "?" prompt or "y/n" question means idle/waiting
    if echo "$content" | tail -5 | grep -qE '\?\s*$|[Yy]/[Nn]|Do you want|Would you like' 2>/dev/null; then
        echo "idle"
        return 0
    fi

    # Detect return to shell prompt (agent exited back to shell)
    if echo "$content" | tail -3 | grep -qE '^[❯\$] *$|^❯ |^\$ $' 2>/dev/null; then
        echo "done"
        return 0
    fi

    echo "idle"
}
