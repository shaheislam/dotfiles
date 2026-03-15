#!/usr/bin/env bash
# aimux provider: GitHub Copilot CLI (via gh copilot)

provider_copilot_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd
    cmd="$(cfg_get "providers.copilot.command" "gh")"
    local args_raw
    args_raw="$(cfg_get "providers.copilot.args" '["copilot"]')"
    local args
    args="$(echo "$args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
    [[ -z "$args" ]] && args="copilot"

    if [[ -n "$prompt" ]]; then
        echo "$cmd $args suggest \"$prompt\""
    else
        echo "$cmd $args"
    fi
}

provider_copilot_detect() {
    local tty="$1"
    # Copilot runs as a gh subprocess
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'gh'
}

provider_copilot_detect_state() {
    local content="$1"

    # Check done patterns first
    local done_raw
    done_raw="$(cfg_get "providers.copilot.done_patterns" '[]')"
    local pattern
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        if echo "$content" | grep -qF "$pattern" 2>/dev/null; then
            echo "done"
            return 0
        fi
    done < <(echo "$done_raw" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Check working pattern
    local working
    working="$(cfg_get "providers.copilot.working_pattern" "")"
    if [[ -n "$working" ]] && echo "$content" | grep -qE "$working" 2>/dev/null; then
        echo "working"
        return 0
    fi

    # Return to shell prompt means idle
    if echo "$content" | tail -3 | grep -qE '^\$\s*$' 2>/dev/null; then
        echo "idle"
        return 0
    fi

    echo "idle"
}
