#!/usr/bin/env bash
# aimux provider: Cursor CLI

provider_cursor_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd
    cmd="$(cfg_get "providers.cursor.command" "cursor")"
    local args_raw
    args_raw="$(cfg_get "providers.cursor.args" '[]')"
    local args
    args="$(echo "$args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"

    if [[ -n "$prompt" ]]; then
        echo "$cmd${args:+ $args} \"$prompt\""
    else
        echo "$cmd${args:+ $args}"
    fi
}

provider_cursor_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'cursor'
}

provider_cursor_detect_state() {
    local content="$1"

    # Check done patterns first
    local done_raw
    done_raw="$(cfg_get "providers.cursor.done_patterns" '[]')"
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
    working="$(cfg_get "providers.cursor.working_pattern" "")"
    if [[ -n "$working" ]] && echo "$content" | grep -qE "$working" 2>/dev/null; then
        echo "working"
        return 0
    fi

    echo "idle"
}
