#!/usr/bin/env bash
# aimux provider: Aider (AI pair programming)

provider_aider_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd
    cmd="$(cfg_get "providers.aider.command" "aider")"
    local args_raw
    args_raw="$(cfg_get "providers.aider.args" '[]')"
    local args
    args="$(echo "$args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"

    if [[ -n "$prompt" ]]; then
        echo "$cmd${args:+ $args} --message \"$prompt\""
    else
        echo "$cmd${args:+ $args}"
    fi
}

provider_aider_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'aider'
}

provider_aider_detect_state() {
    local content="$1"

    # Check done patterns first (higher priority)
    local done_raw
    done_raw="$(cfg_get "providers.aider.done_patterns" '["Applied edit", "Commit "]')"
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
    working="$(cfg_get "providers.aider.working_pattern" "")"
    if [[ -n "$working" ]] && echo "$content" | grep -qE "$working" 2>/dev/null; then
        echo "working"
        return 0
    fi

    # Aider shows ">" prompt when idle
    if echo "$content" | grep -qE '^>' 2>/dev/null; then
        echo "idle"
        return 0
    fi

    echo "idle"
}
