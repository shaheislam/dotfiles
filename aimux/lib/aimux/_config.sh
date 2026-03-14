#!/usr/bin/env bash
# aimux configuration system — TOML parser + env var overrides

AIMUX_CFG_FILE="${AIMUX_HOME}/config.toml"
AIMUX_CFG_DEFAULT="${AIMUX_DIR}/config/default.toml"

# Internal associative array for parsed config
declare -gA _AIMUX_CFG=()

# --- TOML parser (line-by-line, no external deps) ---

_cfg_parse_toml() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local section=""
    local line key val

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip comments (not inside quotes)
        line="${line%%#*}"
        # Trim whitespace
        line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue

        # Section header: [section] or [section.subsection]
        if [[ "$line" =~ ^\[([a-zA-Z0-9_.]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        # Key = value
        if [[ "$line" =~ ^([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"

            # Strip surrounding quotes
            if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                val="${BASH_REMATCH[1]}"
            elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
                val="${BASH_REMATCH[1]}"
            fi

            # Build fully qualified key
            local fqk=""
            if [[ -n "$section" ]]; then
                fqk="${section}.${key}"
            else
                fqk="$key"
            fi

            _AIMUX_CFG["$fqk"]="$val"
        fi
    done <"$file"
}

_cfg_env_key() {
    # Convert "general.poll_interval" -> "AIMUX_POLL_INTERVAL"
    # Convert "providers.claude.command" -> "AIMUX_PROVIDERS_CLAUDE_COMMAND"
    local key="$1"
    # Remove "general." prefix for top-level env vars
    key="${key#general.}"
    echo "AIMUX_${key}" | tr '[:lower:].' '[:upper:]_'
}

# --- Public API ---

cfg_load() {
    _AIMUX_CFG=()

    # Load default config first
    if [[ -f "$AIMUX_CFG_DEFAULT" ]]; then
        _cfg_parse_toml "$AIMUX_CFG_DEFAULT"
    fi

    # Override with user config
    if [[ -f "$AIMUX_CFG_FILE" ]]; then
        _cfg_parse_toml "$AIMUX_CFG_FILE"
    fi

    # Apply env var overrides for known keys
    local fqk env_key env_val
    for fqk in "${!_AIMUX_CFG[@]}"; do
        env_key="$(_cfg_env_key "$fqk")"
        env_val="${!env_key:-}"
        if [[ -n "$env_val" ]]; then
            _AIMUX_CFG["$fqk"]="$env_val"
        fi
    done

    # Export well-known config vars for subshells
    _cfg_export
}

cfg_get() {
    local key="$1"
    local default="${2:-}"
    local val="${_AIMUX_CFG[$key]:-}"

    # Check env var override (allows overrides for keys not in config)
    local env_key
    env_key="$(_cfg_env_key "$key")"
    local env_val="${!env_key:-}"
    if [[ -n "$env_val" ]]; then
        echo "$env_val"
        return 0
    fi

    if [[ -n "$val" ]]; then
        echo "$val"
    else
        echo "$default"
    fi
}

cfg_set() {
    local key="$1" val="$2"
    _AIMUX_CFG["$key"]="$val"
}

cfg_get_array() {
    # Parse TOML array like ["a", "b", "c"] into words
    local key="$1"
    local raw
    raw="$(cfg_get "$key" "[]")"
    # Strip brackets, quotes, commas
    raw="${raw#\[}"
    raw="${raw%\]}"
    echo "$raw" | tr ',' '\n' | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$'
}

_cfg_export() {
    # Export commonly used config values as env vars for child processes
    export AIMUX_POLL_INTERVAL="${_AIMUX_CFG[general.poll_interval]:-10}"
    export AIMUX_STUCK_TIMEOUT="${_AIMUX_CFG[general.stuck_timeout]:-300}"
    export AIMUX_DEFAULT_PROVIDER="${_AIMUX_CFG[general.default_provider]:-claude}"
    export AIMUX_QUEUE_MAX_CONCURRENT="${_AIMUX_CFG[queue.max_concurrent]:-3}"
    export AIMUX_QUEUE_COOLDOWN="${_AIMUX_CFG[queue.cooldown]:-60}"
    export AIMUX_WEBHOOK_URL="${_AIMUX_CFG[notifications.webhook_url]:-}"
}

# Auto-load on source
cfg_load
