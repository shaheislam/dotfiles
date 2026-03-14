#!/usr/bin/env bash
# aimux provider plugin abstraction

# Loaded providers tracker
declare -gA _AIMUX_PROVIDERS_LOADED=()

# Provider search paths (user overrides first, then built-in)
_provider_dirs() {
    local dirs=()
    [[ -d "$AIMUX_HOME/providers" ]] && dirs+=("$AIMUX_HOME/providers")
    [[ -d "$AIMUX_LIB/providers" ]] && dirs+=("$AIMUX_LIB/providers")
    echo "${dirs[@]}"
}

_provider_file() {
    local name="$1"
    local dir
    for dir in $(_provider_dirs); do
        if [[ -f "$dir/${name}.sh" ]]; then
            echo "$dir/${name}.sh"
            return 0
        fi
    done
    return 1
}

provider_load() {
    local name="$1"
    if [[ -n "${_AIMUX_PROVIDERS_LOADED[$name]:-}" ]]; then
        return 0
    fi

    local pfile
    pfile="$(_provider_file "$name")" || {
        error "Provider not found: $name"
        return 1
    }

    # shellcheck disable=SC1090
    source "$pfile"

    # Verify required functions exist
    local fn
    for fn in "provider_${name}_launch_cmd" "provider_${name}_detect" "provider_${name}_detect_state"; do
        if ! declare -f "$fn" &>/dev/null; then
            error "Provider '$name' missing required function: $fn"
            return 1
        fi
    done

    _AIMUX_PROVIDERS_LOADED["$name"]=1
    return 0
}

provider_launch_cmd() {
    local name="$1" worktree="$2" prompt="${3:-}"
    provider_load "$name" || return 1
    "provider_${name}_launch_cmd" "$worktree" "$prompt"
}

provider_detect() {
    local name="$1" tty="$2"
    provider_load "$name" || return 1
    "provider_${name}_detect" "$tty"
}

provider_detect_state() {
    local name="$1" content="$2"
    provider_load "$name" || return 1
    "provider_${name}_detect_state" "$content"
}

provider_list() {
    local dir name
    local -A seen=()
    for dir in $(_provider_dirs); do
        for f in "$dir"/*.sh; do
            [[ -f "$f" ]] || continue
            name="$(basename "$f" .sh)"
            if [[ -z "${seen[$name]:-}" ]]; then
                seen["$name"]=1
                echo "$name"
            fi
        done
    done
}
