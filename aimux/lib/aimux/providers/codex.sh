#!/usr/bin/env bash
# aimux provider: Codex CLI

provider_codex_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd
    cmd="$(cfg_get "providers.codex.command" "codex")"
    local args_raw
    args_raw="$(cfg_get "providers.codex.args" '["--full-auto"]')"
    local args
    args="$(echo "$args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
    [[ -z "$args" ]] && args="--full-auto"

    if [[ -n "$prompt" ]]; then
        echo "$cmd $args \"$prompt\""
    else
        echo "$cmd $args"
    fi
}

provider_codex_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'codex'
}

provider_codex_detect_state() {
    local content="$1"
    local done_raw
    done_raw="$(cfg_get "providers.codex.done_patterns" '["COMPLETE"]')"
    local pattern
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        if echo "$content" | grep -qF "$pattern" 2>/dev/null; then
            echo "done"
            return 0
        fi
    done < <(echo "$done_raw" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    local working
    working="$(cfg_get "providers.codex.working_pattern" "")"
    if [[ -n "$working" ]] && echo "$content" | grep -qE "$working" 2>/dev/null; then
        echo "working"
        return 0
    fi

    echo "idle"
}
