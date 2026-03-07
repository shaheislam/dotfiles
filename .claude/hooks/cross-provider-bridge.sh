#!/usr/bin/env bash
# Cross-Provider Reasoning Bridge - Stop Hook for Claude Code
#
# Sends Claude's reasoning to an independent AI provider for cross-provider
# validation with iterative consensus. The reviewer and Claude exchange
# feedback until consensus is reached or max iterations hit.
#
# Supported providers: codex, gemini, ollama, deepseek, claude, opencode
# Graceful fallback through provider chain → silent continue (zero failures)
#
# Environment variables:
#   CROSS_PROVIDER_BRIDGE=1                     Enable the bridge (default: disabled)
#   CROSS_PROVIDER_ORDER=codex,gemini,ollama    Provider priority/fallback order
#   CROSS_PROVIDER_VERBOSE=1                    Verbose logging to stderr (level 1)
#   CROSS_PROVIDER_VERBOSE=2                    Structured verbose with banners (level 2)
#   CROSS_PROVIDER_MAX_CHARS=4000               Max context chars to send
#   CROSS_PROVIDER_PROMPT=                      Custom review prompt (overrides mode)
#   CROSS_PROVIDER_MODE=review                  Review mode: review|redteam|steelman|assumptions
#   CROSS_PROVIDER_MAX_ITERATIONS=3             Max consensus iterations (1=single-shot)
#   CROSS_PROVIDER_TIMEOUT=120                  Per-provider timeout in seconds
#   CROSS_PROVIDER_LOG=                         Log file path for review history
#   CROSS_PROVIDER_DRY_RUN=1                    Show config and availability without calling providers
#   CROSS_PROVIDER_MODELS=codex=o3,gemini=2.5-pro  Per-provider model overrides (key=value pairs)
#   CROSS_PROVIDER_COOLDOWN=1800                  Fallback cooldown seconds (default: 1800; auto-parsed from error when available)
#   CROSS_PROVIDER_CLAUDE_PROFILES=work,personal  Claude profiles for rotation (auto-discovered from ~/.claude-*/)
#   CROSS_PROVIDER_CODEX_PROFILES=work,personal   Codex profiles for rotation (auto-discovered from ~/.codex-*/)
#
#   Provider-specific model overrides (legacy, still supported):
#   CROSS_PROVIDER_CODEX_MODEL=                 Codex model override (default: gpt-5.4)
#   CROSS_PROVIDER_GEMINI_MODEL=                Gemini model (default: CLI default)
#   CROSS_PROVIDER_OLLAMA_MODEL=qwen3-coder     Ollama model for direct use
#   CROSS_PROVIDER_DEEPSEEK_MODEL=deepseek-r1   DeepSeek model (via Ollama)
#   CROSS_PROVIDER_CLAUDE_MODEL=                 Claude model override (default: claude-opus-4-6)
#   CROSS_PROVIDER_OPENCODE_MODEL=ollama/qwen3-coder  OpenCode model
set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Gate: bridge must be explicitly enabled
if [ "${CROSS_PROVIDER_BRIDGE:-}" != "1" ]; then
    exit 0
fi

# Gate: file-based pause (toggle mid-session without restart)
# Touch ~/.claude/bridge-paused to disable, rm to re-enable
PAUSE_FILE="${CROSS_PROVIDER_PAUSE_FILE:-$HOME/.claude/bridge-paused}"
if [ -f "$PAUSE_FILE" ]; then
    exit 0
fi

# --- Verbose logging ---
VERBOSE="${CROSS_PROVIDER_VERBOSE:-0}"
LOG_FILE="${CROSS_PROVIDER_LOG:-}"
DRY_RUN="${CROSS_PROVIDER_DRY_RUN:-0}"

# Colors for structured verbose output (level 2)
if [ "$VERBOSE" = "2" ] && [ -t 2 ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_MAGENTA=$'\033[35m'
    C_BLUE=$'\033[34m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_CYAN="" C_GREEN="" C_YELLOW="" C_RED="" C_MAGENTA="" C_BLUE=""
fi

log_verbose() {
    if [ "$VERBOSE" = "1" ] || [ "$VERBOSE" = "2" ]; then
        echo "[bridge] $*" >&2
    fi
    if [ -n "$LOG_FILE" ]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${session_id:-unknown}] $*" >>"$LOG_FILE"
    fi
}

# Structured verbose banner (level 2 only)
log_banner() {
    if [ "$VERBOSE" = "2" ]; then
        echo "${C_CYAN}${C_BOLD}═══ $1 ═══${C_RESET}" >&2
    fi
}

log_kv() {
    if [ "$VERBOSE" = "2" ]; then
        printf "  ${C_DIM}%-18s${C_RESET} %s\n" "$1:" "$2" >&2
    fi
}

log_status() {
    local icon="$1" msg="$2"
    if [ "$VERBOSE" = "2" ]; then
        echo "  $icon $msg" >&2
    fi
}

log_verbose "Bridge activated"

# Single jq parse for all input fields (one fork instead of three)
session_id=""
stop_hook_active="false"
transcript_path=""
{
    read -r session_id
    read -r stop_hook_active
    read -r transcript_path
} < <(echo "$INPUT" | timeout 5 jq -r '
    (.session_id // ""),
    (.stop_hook_active // false | tostring),
    (.transcript_path // "")
' 2>/dev/null) || true

log_verbose "session_id=$session_id stop_hook_active=$stop_hook_active"

max_iterations="${CROSS_PROVIDER_MAX_ITERATIONS:-3}"
provider_timeout="${CROSS_PROVIDER_TIMEOUT:-120}"
state_file=""
current_iteration=0
previous_review=""

# --- Parse per-provider model map (CROSS_PROVIDER_MODELS=codex=o3,gemini=2.5-pro) ---
# This overrides individual CROSS_PROVIDER_*_MODEL env vars when set
parse_provider_models() {
    local models_str="${CROSS_PROVIDER_MODELS:-}"
    if [ -z "$models_str" ]; then
        return
    fi
    IFS=',' read -ra pairs <<<"$models_str"
    for pair in "${pairs[@]}"; do
        local key="${pair%%=*}"
        local val="${pair#*=}"
        key="${key#"${key%%[![:space:]]*}"}" # trim
        key="${key%"${key##*[![:space:]]}"}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        case "$key" in
        codex) export CROSS_PROVIDER_CODEX_MODEL="$val" ;;
        gemini) export CROSS_PROVIDER_GEMINI_MODEL="$val" ;;
        ollama) export CROSS_PROVIDER_OLLAMA_MODEL="$val" ;;
        deepseek) export CROSS_PROVIDER_DEEPSEEK_MODEL="$val" ;;
        claude) export CROSS_PROVIDER_CLAUDE_MODEL="$val" ;;
        opencode) export CROSS_PROVIDER_OPENCODE_MODEL="$val" ;;
        *) log_verbose "Unknown provider in CROSS_PROVIDER_MODELS: $key (skipping)" ;;
        esac
    done
}
parse_provider_models

# --- Default models (single source of truth for provider functions + dispatch) ---
DEFAULT_CODEX_MODEL="${CROSS_PROVIDER_CODEX_MODEL:-gpt-5.4}"
DEFAULT_GEMINI_MODEL="${CROSS_PROVIDER_GEMINI_MODEL:-}"
DEFAULT_OLLAMA_MODEL="${CROSS_PROVIDER_OLLAMA_MODEL:-qwen3-coder}"
DEFAULT_DEEPSEEK_MODEL="${CROSS_PROVIDER_DEEPSEEK_MODEL:-deepseek-r1}"
DEFAULT_CLAUDE_MODEL="${CROSS_PROVIDER_CLAUDE_MODEL:-claude-opus-4-6}"
DEFAULT_OPENCODE_MODEL="${CROSS_PROVIDER_OPENCODE_MODEL:-ollama/qwen3-coder}"

# --- Rate limit auto-rotation ---
COOLDOWN_FILE="/tmp/cross-provider-cooldowns.json"
COOLDOWN_SECONDS="${CROSS_PROVIDER_COOLDOWN:-1800}"
PROVIDER_STDERR_FILE="/tmp/cross-provider-bridge-stderr.$$"
trap 'rm -f "$PROVIDER_STDERR_FILE"' EXIT

# Verify jq is available (required for cooldown tracking)
if ! command -v jq &>/dev/null; then
    log_verbose "WARNING: jq not found — cooldown tracking disabled (install jq for rate limit rotation)"
fi

# Prune expired entries from cooldown file on startup
if [ -f "$COOLDOWN_FILE" ] && command -v jq &>/dev/null; then
    _now=$(date +%s)
    _pruned=$(timeout 2 jq --argjson now "$_now" 'with_entries(select(.value > $now))' "$COOLDOWN_FILE" 2>/dev/null) || true
    if [ -n "$_pruned" ]; then
        echo "$_pruned" >"${COOLDOWN_FILE}.tmp.$$" && mv "${COOLDOWN_FILE}.tmp.$$" "$COOLDOWN_FILE"
    fi
fi

# Auto-discover profiles if not explicitly set
# Scans for ~/.claude-*/ and ~/.codex-*/ directories
# Only includes profiles with actual credential files
if [ -z "${CROSS_PROVIDER_CLAUDE_PROFILES:-}" ]; then
    _auto_claude_profiles=""
    for d in "$HOME"/.claude-*/; do
        [ -d "$d" ] || continue
        _name="${d%/}"               # strip trailing slash
        _name="${_name##*/.claude-}" # extract profile name
        [ -z "$_name" ] && continue
        # Validate: must have credentials (OAuth or API key)
        if [ ! -f "$d/credentials.json" ] && [ ! -f "$d/.credentials.json" ] && [ ! -f "$d/settings.json" ]; then
            log_verbose "Auto-discover: skipping ~/.claude-$_name (no credentials)"
            continue
        fi
        [ -n "$_auto_claude_profiles" ] && _auto_claude_profiles="${_auto_claude_profiles},"
        _auto_claude_profiles="${_auto_claude_profiles}${_name}"
    done
    if [ -n "$_auto_claude_profiles" ]; then
        export CROSS_PROVIDER_CLAUDE_PROFILES="$_auto_claude_profiles"
        log_verbose "Auto-discovered Claude profiles: $CROSS_PROVIDER_CLAUDE_PROFILES"
    fi
fi
if [ -z "${CROSS_PROVIDER_CODEX_PROFILES:-}" ]; then
    _auto_codex_profiles=""
    for d in "$HOME"/.codex-*/; do
        [ -d "$d" ] || continue
        _name="${d%/}"
        _name="${_name##*/.codex-}"
        [ -z "$_name" ] && continue
        # Validate: must have auth file or config
        if [ ! -f "$d/auth.json" ] && [ ! -f "$d/config.toml" ]; then
            log_verbose "Auto-discover: skipping ~/.codex-$_name (no auth)"
            continue
        fi
        [ -n "$_auto_codex_profiles" ] && _auto_codex_profiles="${_auto_codex_profiles},"
        _auto_codex_profiles="${_auto_codex_profiles}${_name}"
    done
    if [ -n "$_auto_codex_profiles" ]; then
        export CROSS_PROVIDER_CODEX_PROFILES="$_auto_codex_profiles"
        log_verbose "Auto-discovered Codex profiles: $CROSS_PROVIDER_CODEX_PROFILES"
    fi
fi

# Detect rate limit indicators in provider output/stderr
detect_rate_limit() {
    local output="$1" stderr_output="${2:-}"
    local combined="${output} ${stderr_output}"
    if echo "$combined" | grep -qi \
        -e 'rate.limit' \
        -e 'rate_limit' \
        -e '429' \
        -e 'too many requests' \
        -e 'quota.exceeded' \
        -e 'RESOURCE_EXHAUSTED' \
        -e 'overloaded_error' \
        -e 'throttl' \
        -e 'usage.limit' \
        -e 'capacity.exceeded' \
        -e 'try again later'; then
        return 0
    fi
    return 1
}

# Extract cooldown duration (in seconds) from rate limit error messages
# Returns the parsed duration, or empty string if unparsable
# Patterns handled:
#   "Try again in 3h 42m"           → Codex
#   "try again in 1.152s"           → OpenAI API
#   "reset at 3pm"                  → Claude (absolute time)
#   "reset at 3pm (America/New_York)" → Claude with timezone
#   "Please retry after Xs"         → Generic retry-after
extract_reset_seconds() {
    local combined="$1"

    # Pattern: "Try again in Xh Ym" or "try again in Xh" or "try again in Ym"
    local hm_match
    hm_match=$(echo "$combined" | grep -oi '[Tt]ry again in [0-9]*h *[0-9]*m\|[Tt]ry again in [0-9]*h\|[Tt]ry again in [0-9]*m' | head -1)
    if [ -n "$hm_match" ]; then
        local hours=0 minutes=0
        hours=$(echo "$hm_match" | grep -o '[0-9]*h' | grep -o '[0-9]*') || true
        minutes=$(echo "$hm_match" | grep -o '[0-9]*m' | grep -o '[0-9]*') || true
        [ -z "$hours" ] && hours=0
        [ -z "$minutes" ] && minutes=0
        local total=$((hours * 3600 + minutes * 60))
        if [ "$total" -gt 0 ]; then
            echo "$total"
            return
        fi
    fi

    # Pattern: "try again in X.Xs" or "retry after Xs"
    local sec_match
    sec_match=$(echo "$combined" | grep -oi 'try again in [0-9.]*s\|retry after [0-9.]*s' | head -1)
    if [ -n "$sec_match" ]; then
        local secs
        secs=$(echo "$sec_match" | grep -o '[0-9.]*s' | grep -o '[0-9]*' | head -1)
        if [ -n "$secs" ] && [ "$secs" -gt 0 ] 2>/dev/null; then
            echo "$secs"
            return
        fi
    fi

    # Pattern: "reset at Xpm" or "reset at Xam" or "reset at X:XXpm"
    local time_match
    time_match=$(echo "$combined" | grep -oi 'reset at [0-9:]*[ap]m' | head -1)
    if [ -n "$time_match" ]; then
        local reset_time
        reset_time=$(echo "$time_match" | grep -oi '[0-9:]*[ap]m' | head -1)
        if [ -n "$reset_time" ]; then
            local reset_epoch now_epoch
            # macOS (BSD date)
            if date -j -f "%I:%M%p" "12:00AM" +%s &>/dev/null; then
                reset_epoch=$(date -j -f "%I:%M%p" "$reset_time" +%s 2>/dev/null) ||
                    reset_epoch=$(date -j -f "%I%p" "$reset_time" +%s 2>/dev/null) || true
            # Linux (GNU date)
            elif date -d "12:00AM" +%s &>/dev/null; then
                reset_epoch=$(date -d "$reset_time" +%s 2>/dev/null) || true
            fi
            if [ -n "$reset_epoch" ]; then
                now_epoch=$(date +%s)
                local delta=$((reset_epoch - now_epoch))
                # If negative, it means tomorrow
                [ "$delta" -le 0 ] && delta=$((delta + 86400))
                echo "$delta"
                return
            fi
        fi
    fi

    # No parseable reset time found
    echo ""
}

# Check if a provider is in cooldown
is_provider_cooled_down() {
    local provider_key="$1"
    [ -f "$COOLDOWN_FILE" ] || return 1
    local expiry
    expiry=$(timeout 2 jq -r --arg key "$provider_key" '.[$key] // 0' "$COOLDOWN_FILE" 2>/dev/null) || return 1
    local now
    now=$(date +%s)
    [ "$expiry" -gt "$now" ] 2>/dev/null
}

# Record cooldown for a provider
# Usage: set_provider_cooldown <key> [error_output]
# If error_output contains a parseable reset time, uses that.
# Otherwise falls back to COOLDOWN_SECONDS.
# Uses flock for atomic writes when multiple sessions share the cooldown file.
set_provider_cooldown() {
    local provider_key="$1"
    local error_output="${2:-}"
    local cooldown_duration="$COOLDOWN_SECONDS"

    # Try to extract actual reset time from error message
    if [ -n "$error_output" ]; then
        local parsed
        parsed=$(extract_reset_seconds "$error_output")
        if [ -n "$parsed" ] && [ "$parsed" -gt 0 ] 2>/dev/null; then
            cooldown_duration="$parsed"
            log_verbose "Provider $provider_key: parsed reset time ${cooldown_duration}s from error"
        fi
    fi

    local now expiry
    now=$(date +%s)
    expiry=$((now + cooldown_duration))

    # Atomic write with flock (handles concurrent sessions)
    local lockfile="${COOLDOWN_FILE}.lock"
    (
        # flock fd 9; timeout to avoid deadlock
        if command -v flock &>/dev/null; then
            flock -w 5 9 2>/dev/null || true
        fi
        # Re-read file inside lock to avoid lost updates
        if [ -f "$COOLDOWN_FILE" ]; then
            timeout 2 jq --arg key "$provider_key" --argjson exp "$expiry" \
                '.[$key] = $exp' "$COOLDOWN_FILE" >"${COOLDOWN_FILE}.tmp.$$" 2>/dev/null &&
                mv "${COOLDOWN_FILE}.tmp.$$" "$COOLDOWN_FILE"
        else
            timeout 2 jq -n --arg key "$provider_key" --argjson exp "$expiry" \
                '{($key): $exp}' >"$COOLDOWN_FILE" 2>/dev/null
        fi
    ) 9>"$lockfile"
    rm -f "$lockfile" 2>/dev/null

    log_verbose "Provider $provider_key cooled down for ${cooldown_duration}s"
}

# Get remaining cooldown seconds (for display)
get_cooldown_remaining() {
    local provider_key="$1"
    [ -f "$COOLDOWN_FILE" ] || {
        echo "0"
        return
    }
    local expiry
    expiry=$(timeout 2 jq -r --arg key "$provider_key" '.[$key] // 0' "$COOLDOWN_FILE" 2>/dev/null) || {
        echo "0"
        return
    }
    local now remaining
    now=$(date +%s)
    remaining=$((expiry - now))
    [ "$remaining" -gt 0 ] && echo "$remaining" || echo "0"
}

# Check if ALL claude profiles are cooled down
all_claude_profiles_cooled() {
    local profiles_str="${CROSS_PROVIDER_CLAUDE_PROFILES:-}"
    [ -z "$profiles_str" ] && return 1
    IFS=',' read -ra profs <<<"$profiles_str"
    for prof in "${profs[@]}"; do
        prof="${prof#"${prof%%[![:space:]]*}"}"
        prof="${prof%"${prof##*[![:space:]]}"}"
        is_provider_cooled_down "claude:$prof" || return 1
    done
    return 0
}

# Check if ALL codex profiles are cooled down
all_codex_profiles_cooled() {
    local profiles_str="${CROSS_PROVIDER_CODEX_PROFILES:-}"
    [ -z "$profiles_str" ] && return 1
    IFS=',' read -ra profs <<<"$profiles_str"
    for prof in "${profs[@]}"; do
        prof="${prof#"${prof%%[![:space:]]*}"}"
        prof="${prof%"${prof##*[![:space:]]}"}"
        is_provider_cooled_down "codex:$prof" || return 1
    done
    return 0
}

if [ -n "$session_id" ]; then
    state_file="/tmp/cross-provider-bridge-${session_id}.json"
fi

if [ "$stop_hook_active" = "true" ]; then
    # No state file or no session_id → safety exit (backward compat)
    if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
        log_verbose "No state file found, exiting (safety fallback)"
        exit 0
    fi
    # Stale check (>10 min — shorter window for faster crash recovery)
    created_at=$(timeout 5 jq -r '.created_at // 0' "$state_file" 2>/dev/null)
    now=$(date +%s)
    if [ $((now - created_at)) -gt 600 ]; then
        log_verbose "State file stale (>10min), cleaning up"
        rm -f "$state_file"
        exit 0
    fi
    # Max iterations check
    current_iteration=$(timeout 5 jq -r '.iteration // 0' "$state_file" 2>/dev/null)
    if [ "$current_iteration" -ge "$max_iterations" ]; then
        log_verbose "Max iterations reached ($current_iteration/$max_iterations), allowing stop"
        rm -f "$state_file"
        exit 0
    fi
    # Load previous review for follow-up prompt
    previous_review=$(timeout 5 jq -r '.previous_reviews[-1] // empty' "$state_file" 2>/dev/null)
fi

# Strip provider CLI metadata, extracting only the model's response content
# Codex CLI wraps responses in timestamped headers, echoed prompts, and thinking blocks
strip_provider_metadata() {
    local output="$1"
    # Codex CLI: response follows last "] codex" line, ends before "] tokens used:"
    if echo "$output" | grep -q '^\[.*\] codex$'; then
        local cleaned
        cleaned=$(echo "$output" | awk '
            /^\[.*\] codex$/ { content = ""; collecting = 1; next }
            /^\[.*\] tokens used:/ { next }
            collecting { content = content "\n" $0 }
            END { sub(/^\n+/, "", content); print content }
        ')
        if [ -n "$cleaned" ]; then
            echo "$cleaned"
            return
        fi
    fi
    # Gemini CLI: strip any ANSI escape codes and spinner output
    if echo "$output" | grep -q $'\033'; then
        local cleaned
        cleaned=$(echo "$output" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | sed '/^$/d')
        if [ -n "$cleaned" ]; then
            echo "$cleaned"
            return
        fi
    fi
    # No known metadata pattern — return as-is
    echo "$output"
}

# Strip thinking blocks common in reasoning models (<think>...</think>, <thinking>...</thinking>)
# Applied to ALL provider output to prevent false consensus from heuristic phrases in thinking blocks
strip_thinking_blocks() {
    local output="$1"
    if echo "$output" | grep -q '<think\(ing\)\?>'; then
        local cleaned
        cleaned=$(echo "$output" | sed '/<think\(ing\)\?>/,/<\/think\(ing\)\?>/d' | sed '/^[[:space:]]*$/d')
        if [ -n "$cleaned" ]; then
            echo "$cleaned"
            return
        fi
    fi
    echo "$output"
}

# Consensus detection: check if reviewer output indicates agreement
detect_consensus() {
    local output="$1"
    local first_line
    first_line=$(echo "$output" | head -1)
    # Primary: keyword prefix (case-insensitive)
    if echo "$first_line" | grep -qi '^CONSENSUS:'; then
        log_verbose "Consensus detected: explicit CONSENSUS: prefix"
        return 0
    fi
    # Skip heuristic if reviewer explicitly flagged concerns
    if echo "$first_line" | grep -qi '^CONCERNS:'; then
        log_verbose "No consensus: explicit CONCERNS: prefix"
        return 1
    fi
    # Heuristic fallback (only when no explicit prefix)
    if echo "$output" | grep -qi \
        -e 'all concerns addressed' \
        -e 'no remaining issues' \
        -e 'no further concerns' \
        -e 'reasoning is sound' \
        -e 'adequately addressed'; then
        log_verbose "Consensus detected: heuristic keyword match"
        return 0
    fi
    log_verbose "No consensus: no explicit prefix or heuristic match"
    return 1
}

# --- Provider availability checks ---

check_provider_available() {
    local provider="$1"
    case "$provider" in
    codex)
        command -v codex &>/dev/null && return 0
        ;;
    gemini)
        command -v gemini &>/dev/null && return 0
        ;;
    ollama)
        command -v ollama &>/dev/null && curl -sf http://localhost:11434/api/tags &>/dev/null && return 0
        ;;
    deepseek)
        command -v ollama &>/dev/null && curl -sf http://localhost:11434/api/tags &>/dev/null && return 0
        ;;
    claude)
        command -v claude &>/dev/null && return 0
        ;;
    opencode)
        command -v opencode &>/dev/null && return 0
        ;;
    esac
    return 1
}

get_provider_model() {
    local provider="$1"
    case "$provider" in
    codex) echo "${DEFAULT_CODEX_MODEL:-(CLI default)}" ;;
    gemini) echo "${DEFAULT_GEMINI_MODEL:-(CLI default)}" ;;
    ollama) echo "$DEFAULT_OLLAMA_MODEL" ;;
    deepseek) echo "$DEFAULT_DEEPSEEK_MODEL" ;;
    claude) echo "$DEFAULT_CLAUDE_MODEL" ;;
    opencode) echo "$DEFAULT_OPENCODE_MODEL" ;;
    *) echo "(unknown)" ;;
    esac
}

get_provider_display_name() {
    local provider="$1"
    local model
    model=$(get_provider_model "$provider")
    case "$provider" in
    codex) echo "Codex${DEFAULT_CODEX_MODEL:+ ($DEFAULT_CODEX_MODEL)}" ;;
    gemini) echo "Gemini${DEFAULT_GEMINI_MODEL:+ ($DEFAULT_GEMINI_MODEL)}" ;;
    ollama) echo "Ollama ($DEFAULT_OLLAMA_MODEL)" ;;
    deepseek) echo "DeepSeek ($DEFAULT_DEEPSEEK_MODEL)" ;;
    claude) echo "Claude ($DEFAULT_CLAUDE_MODEL)" ;;
    opencode) echo "OpenCode ($DEFAULT_OPENCODE_MODEL)" ;;
    *) echo "$provider" ;;
    esac
}

# --- Provider implementations ---

# Each provider function receives the prompt on stdin and outputs the review on stdout.
# Returns 0 on success, 1 on failure.

provider_codex() {
    local prompt="$1"
    if ! command -v codex &>/dev/null; then
        log_verbose "Provider codex: binary not found"
        return 1
    fi

    # Profile rotation: try each profile, skipping cooled-down ones
    local profiles_str="${CROSS_PROVIDER_CODEX_PROFILES:-}"
    if [ -n "$profiles_str" ]; then
        IFS=',' read -ra profiles <<<"$profiles_str"
        for profile in "${profiles[@]}"; do
            profile="${profile#"${profile%%[![:space:]]*}"}"
            profile="${profile%"${profile##*[![:space:]]}"}"
            local profile_key="codex:$profile"
            local codex_home="$HOME/.codex-$profile"

            if is_provider_cooled_down "$profile_key"; then
                local remaining
                remaining=$(get_cooldown_remaining "$profile_key")
                log_verbose "Provider codex (profile=$profile): cooled down (${remaining}s remaining)"
                if [ "$VERBOSE" = "2" ]; then
                    log_status "${C_YELLOW}⏳${C_RESET}" "codex:$profile ${C_DIM}(cooled down, ${remaining}s)${C_RESET}"
                fi
                continue
            fi

            if [ ! -d "$codex_home" ]; then
                log_verbose "Provider codex (profile=$profile): CODEX_HOME not found ($codex_home)"
                continue
            fi

            local codex_cmd=(codex exec)
            if [ -n "$DEFAULT_CODEX_MODEL" ]; then
                codex_cmd+=(--model "$DEFAULT_CODEX_MODEL")
            fi
            log_verbose "Provider codex (profile=$profile): running ${codex_cmd[*]}"
            local output stderr_content
            output=$(echo "$prompt" | env CODEX_HOME="$codex_home" timeout "$provider_timeout" "${codex_cmd[@]}" - 2>"$PROVIDER_STDERR_FILE") || true
            stderr_content=""
            [ -f "$PROVIDER_STDERR_FILE" ] && stderr_content=$(cat "$PROVIDER_STDERR_FILE" 2>/dev/null)

            if [ -n "$output" ] && ! detect_rate_limit "$output" "$stderr_content"; then
                echo "$output"
                return 0
            fi

            # Rate limited or no output — check and set cooldown
            if detect_rate_limit "${output:-}" "$stderr_content"; then
                local _err_combined="${output:-} ${stderr_content}"
                set_provider_cooldown "$profile_key" "$_err_combined"
                local _cd_display
                _cd_display=$(get_cooldown_remaining "$profile_key")
                log_verbose "Provider codex (profile=$profile): rate limited, cooling down (${_cd_display}s)"
                if [ "$VERBOSE" = "2" ]; then
                    log_status "${C_RED}⚡${C_RESET}" "codex:$profile ${C_DIM}(rate limited, cooling ${_cd_display}s)${C_RESET}"
                fi
            else
                log_verbose "Provider codex (profile=$profile): no output"
            fi
        done
        return 1
    fi

    # Single-profile (default) path — no profile rotation
    local codex_cmd=(codex exec)
    if [ -n "$DEFAULT_CODEX_MODEL" ]; then
        codex_cmd+=(--model "$DEFAULT_CODEX_MODEL")
    fi
    log_verbose "Provider codex: running ${codex_cmd[*]}"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" "${codex_cmd[@]}" - 2>"$PROVIDER_STDERR_FILE") || true
    if [ -n "$output" ]; then
        echo "$output"
        return 0
    fi
    log_verbose "Provider codex: no output"
    return 1
}

provider_gemini() {
    local prompt="$1"
    if ! command -v gemini &>/dev/null; then
        log_verbose "Provider gemini: binary not found"
        return 1
    fi
    local gemini_cmd=(gemini)
    if [ -n "$DEFAULT_GEMINI_MODEL" ]; then
        gemini_cmd+=(--model "$DEFAULT_GEMINI_MODEL")
    fi
    log_verbose "Provider gemini: running ${gemini_cmd[*]}"
    local output
    # Gemini CLI: positional prompt for non-interactive one-shot mode
    output=$(timeout "$provider_timeout" "${gemini_cmd[@]}" "$prompt" 2>"$PROVIDER_STDERR_FILE") || true
    if [ -n "$output" ]; then
        echo "$output"
        return 0
    fi
    log_verbose "Provider gemini: no output"
    return 1
}

provider_ollama() {
    local prompt="$1"
    if ! command -v ollama &>/dev/null; then
        log_verbose "Provider ollama: binary not found"
        return 1
    fi
    # Check if Ollama server is running
    if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
        log_verbose "Provider ollama: server not running"
        return 1
    fi
    log_verbose "Provider ollama: running model=$DEFAULT_OLLAMA_MODEL"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" ollama run "$DEFAULT_OLLAMA_MODEL" 2>"$PROVIDER_STDERR_FILE") || true
    if [ -n "$output" ]; then
        echo "$output"
        return 0
    fi
    log_verbose "Provider ollama: no output"
    return 1
}

provider_deepseek() {
    local prompt="$1"
    # DeepSeek runs via Ollama with the deepseek model
    if ! command -v ollama &>/dev/null; then
        log_verbose "Provider deepseek: ollama binary not found"
        return 1
    fi
    if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
        log_verbose "Provider deepseek: ollama server not running"
        return 1
    fi
    log_verbose "Provider deepseek: running model=$DEFAULT_DEEPSEEK_MODEL via ollama"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" ollama run "$DEFAULT_DEEPSEEK_MODEL" 2>"$PROVIDER_STDERR_FILE") || true
    if [ -n "$output" ]; then
        echo "$output"
        return 0
    fi
    log_verbose "Provider deepseek: no output"
    return 1
}

provider_claude() {
    local prompt="$1"
    if ! command -v claude &>/dev/null; then
        log_verbose "Provider claude: binary not found"
        return 1
    fi

    # Profile rotation: try each profile, skipping cooled-down ones
    local profiles_str="${CROSS_PROVIDER_CLAUDE_PROFILES:-}"
    if [ -n "$profiles_str" ]; then
        IFS=',' read -ra profiles <<<"$profiles_str"
        for profile in "${profiles[@]}"; do
            profile="${profile#"${profile%%[![:space:]]*}"}"
            profile="${profile%"${profile##*[![:space:]]}"}"
            local profile_key="claude:$profile"
            local config_dir="$HOME/.claude-$profile"

            if is_provider_cooled_down "$profile_key"; then
                local remaining
                remaining=$(get_cooldown_remaining "$profile_key")
                log_verbose "Provider claude (profile=$profile): cooled down (${remaining}s remaining)"
                if [ "$VERBOSE" = "2" ]; then
                    log_status "${C_YELLOW}⏳${C_RESET}" "claude:$profile ${C_DIM}(cooled down, ${remaining}s)${C_RESET}"
                fi
                continue
            fi

            if [ ! -d "$config_dir" ]; then
                log_verbose "Provider claude (profile=$profile): config dir not found ($config_dir)"
                continue
            fi

            log_verbose "Provider claude (profile=$profile): running model=$DEFAULT_CLAUDE_MODEL"
            local output stderr_content
            output=$(echo "$prompt" | env CLAUDE_CONFIG_DIR="$config_dir" timeout "$provider_timeout" claude -p --model "$DEFAULT_CLAUDE_MODEL" 2>"$PROVIDER_STDERR_FILE") || true
            stderr_content=""
            [ -f "$PROVIDER_STDERR_FILE" ] && stderr_content=$(cat "$PROVIDER_STDERR_FILE" 2>/dev/null)

            if [ -n "$output" ] && ! detect_rate_limit "$output" "$stderr_content"; then
                echo "$output"
                return 0
            fi

            # Rate limited or no output — check and set cooldown
            if detect_rate_limit "${output:-}" "$stderr_content"; then
                local _err_combined="${output:-} ${stderr_content}"
                set_provider_cooldown "$profile_key" "$_err_combined"
                local _cd_display
                _cd_display=$(get_cooldown_remaining "$profile_key")
                log_verbose "Provider claude (profile=$profile): rate limited, cooling down (${_cd_display}s)"
                if [ "$VERBOSE" = "2" ]; then
                    log_status "${C_RED}⚡${C_RESET}" "claude:$profile ${C_DIM}(rate limited, cooling ${_cd_display}s)${C_RESET}"
                fi
            else
                log_verbose "Provider claude (profile=$profile): no output"
            fi
        done
        return 1
    fi

    # Single-profile (default) path — no profile rotation
    log_verbose "Provider claude: running model=$DEFAULT_CLAUDE_MODEL"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" claude -p --model "$DEFAULT_CLAUDE_MODEL" 2>"$PROVIDER_STDERR_FILE") || true
    if [ -n "$output" ]; then
        echo "$output"
        return 0
    fi
    log_verbose "Provider claude: no output"
    return 1
}

provider_opencode() {
    local prompt="$1"
    if ! command -v opencode &>/dev/null; then
        log_verbose "Provider opencode: binary not found"
        return 1
    fi
    log_verbose "Provider opencode: running model=$DEFAULT_OPENCODE_MODEL"
    local output
    output=$(timeout "$provider_timeout" opencode run --model "$DEFAULT_OPENCODE_MODEL" "$prompt" 2>"$PROVIDER_STDERR_FILE") || true
    if [ -n "$output" ]; then
        echo "$output"
        return 0
    fi
    log_verbose "Provider opencode: no output"
    return 1
}

# --- Main logic ---

# Validate transcript path (already parsed from input above)
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    log_verbose "No valid transcript path, exiting"
    exit 0
fi

# Extract last assistant message — tail-first for performance on large transcripts
# JSONL messages are single lines; 500 covers sessions with many tool calls
last_response=$(tail -500 "$transcript_path" | timeout 10 jq -rs '
    [.[] | select(
        .role == "assistant" or
        .type == "assistant" or
        ((.message // {}).role // "" | test("assistant"))
    )] | last //empty |
    if .content | type == "string" then .content
    elif .content | type == "array" then
        [.content[] | select(.type == "text") | .text] | join("\n")
    elif (.message // {}).content | type == "string" then .message.content
    elif (.message // {}).content | type == "array" then
        [.message.content[] | select(.type == "text") | .text] | join("\n")
    else empty
    end
' 2>/dev/null) || true

if [ -z "$last_response" ]; then
    log_verbose "No assistant response found in transcript"
    exit 0
fi

# Truncate to reasonable size
max_chars="${CROSS_PROVIDER_MAX_CHARS:-4000}"
last_response="${last_response:0:$max_chars}"

log_verbose "Extracted ${#last_response} chars from transcript (max: $max_chars)"

# --- Structured verbose configuration display ---
IFS=',' read -ra providers <<<"${CROSS_PROVIDER_ORDER:-codex,opencode}"
bridge_mode="${CROSS_PROVIDER_MODE:-review}"

if [ "$VERBOSE" = "2" ]; then
    echo "" >&2
    log_banner "Cross-Provider Bridge"
    log_kv "Session" "${session_id:-unknown}"
    log_kv "Iteration" "$((current_iteration + 1))/$max_iterations"
    log_kv "Mode" "$bridge_mode"
    log_kv "Timeout" "${provider_timeout}s per provider"
    log_kv "Max chars" "$max_chars"
    log_kv "Context size" "${#last_response} chars"
    if [ -n "${CROSS_PROVIDER_MODELS:-}" ]; then
        log_kv "Model map" "${CROSS_PROVIDER_MODELS}"
    fi
    if [ -n "$LOG_FILE" ]; then
        log_kv "Log file" "$LOG_FILE"
    fi
    echo "" >&2

    # Provider availability preflight
    log_banner "Provider Availability"
    for p in "${providers[@]}"; do
        p="${p#"${p%%[![:space:]]*}"}"
        p="${p%"${p##*[![:space:]]}"}"
        local_model=$(get_provider_model "$p")
        if check_provider_available "$p"; then
            # Check cooldown status
            if [ "$p" = "claude" ] && [ -n "${CROSS_PROVIDER_CLAUDE_PROFILES:-}" ]; then
                if all_claude_profiles_cooled; then
                    log_status "${C_YELLOW}⏳${C_RESET}" "${C_BOLD}$p${C_RESET} ${C_DIM}(all profiles cooled down)${C_RESET}"
                else
                    log_status "${C_GREEN}✓${C_RESET}" "${C_BOLD}$p${C_RESET} ${C_DIM}(model: $local_model, profiles: ${CROSS_PROVIDER_CLAUDE_PROFILES})${C_RESET}"
                fi
            elif [ "$p" = "codex" ] && [ -n "${CROSS_PROVIDER_CODEX_PROFILES:-}" ]; then
                if all_codex_profiles_cooled; then
                    log_status "${C_YELLOW}⏳${C_RESET}" "${C_BOLD}$p${C_RESET} ${C_DIM}(all profiles cooled down)${C_RESET}"
                else
                    log_status "${C_GREEN}✓${C_RESET}" "${C_BOLD}$p${C_RESET} ${C_DIM}(model: $local_model, profiles: ${CROSS_PROVIDER_CODEX_PROFILES})${C_RESET}"
                fi
            elif is_provider_cooled_down "$p"; then
                local_remaining=$(get_cooldown_remaining "$p")
                log_status "${C_YELLOW}⏳${C_RESET}" "${C_BOLD}$p${C_RESET} ${C_DIM}(cooled down, ${local_remaining}s)${C_RESET}"
            else
                log_status "${C_GREEN}✓${C_RESET}" "${C_BOLD}$p${C_RESET} ${C_DIM}(model: $local_model)${C_RESET}"
            fi
        else
            log_status "${C_RED}✗${C_RESET}" "${C_BOLD}$p${C_RESET} ${C_DIM}(unavailable)${C_RESET}"
        fi
    done
    echo "" >&2
fi

# --- Dry-run mode: show config and exit ---
if [ "$DRY_RUN" = "1" ]; then
    if [ "$VERBOSE" != "2" ]; then
        # Print config even without VERBOSE=2 in dry-run mode
        echo "[bridge] Dry-run mode — showing configuration" >&2
        echo "[bridge] Providers: ${providers[*]}" >&2
        echo "[bridge] Mode: $bridge_mode" >&2
        echo "[bridge] Max iterations: $max_iterations" >&2
        echo "[bridge] Timeout: ${provider_timeout}s" >&2
        echo "[bridge] Context: ${#last_response} chars" >&2
        for p in "${providers[@]}"; do
            p="${p#"${p%%[![:space:]]*}"}"
            p="${p%"${p##*[![:space:]]}"}"
            if check_provider_available "$p"; then
                echo "[bridge] Provider $p: available (model: $(get_provider_model "$p"))" >&2
            else
                echo "[bridge] Provider $p: unavailable" >&2
            fi
        done
    else
        log_banner "Dry Run Complete"
    fi
    exit 0
fi

# Build review prompt: initial vs follow-up
if [ "$current_iteration" -gt 0 ] && [ -n "$previous_review" ]; then
    # Follow-up prompt: check if previous concerns were addressed
    full_prompt="You previously reviewed an AI model's work and raised these concerns:

---
Previous review:
${previous_review}
---

The model has now updated its response:

---
Updated reasoning:
${last_response}
---

Check whether your previous concerns were adequately addressed.
- If ALL concerns are resolved, start your response with \"CONSENSUS:\" followed by brief confirmation.
- If concerns remain, start with \"CONCERNS:\" followed by specific actionable feedback.
Focus only on whether previous concerns were addressed."
    if [ "$VERBOSE" = "2" ]; then
        log_banner "Follow-up Review (iteration $((current_iteration + 1)))"
        log_kv "Previous concerns" "$(echo "$previous_review" | head -3 | tr '\n' ' ')..."
    fi
else
    # Initial review prompt - mode-based selection
    # Validate CROSS_PROVIDER_MODE (whitelist known values, reject unknown)
    case "$bridge_mode" in
    review | redteam | steelman | assumptions) ;; # valid
    *)
        log_verbose "Unknown CROSS_PROVIDER_MODE='$bridge_mode', falling back to 'review'"
        bridge_mode="review"
        ;;
    esac
    if [ -n "${CROSS_PROVIDER_PROMPT:-}" ]; then
        review_prompt="$CROSS_PROVIDER_PROMPT"
    else
        case "$bridge_mode" in
        redteam)
            review_prompt="You are a hostile adversarial reviewer. Your job is to BREAK this plan. Find: 1) Fatal flaws that would cause project failure. 2) Hidden assumptions that are wrong. 3) Missing failure modes that aren't addressed. 4) Optimistic estimates that will slip. 5) Dependencies that will break. Be specific and ruthless. If you genuinely cannot find issues, start with \"CONSENSUS:\" — otherwise start with \"CONCERNS:\" and list them."
            ;;
        steelman)
            review_prompt="You are an advocate for this approach. Build the STRONGEST possible case for why this reasoning is correct and this plan will succeed. Find: 1) Strengths that aren't explicitly stated. 2) Why potential concerns are manageable. 3) Evidence supporting the approach. 4) Advantages over alternatives. Start with \"CONSENSUS:\" and make the strongest case. If you find genuine fatal flaws you cannot steelman, start with \"CONCERNS:\"."
            ;;
        assumptions)
            review_prompt="You are a first-principles analyst. Decompose the reasoning into its fundamental assumptions. For each assumption: 1) State it explicitly. 2) Grade confidence: high/medium/low. 3) How to verify it. 4) What changes if it's wrong. Do NOT accept any claim at face value. If all assumptions are well-grounded, start with \"CONSENSUS:\". If critical assumptions are unverified or wrong, start with \"CONCERNS:\" and list them."
            ;;
        *)
            review_prompt="You are an independent AI reviewer checking another AI model's work for correlation bias. Review the reasoning below and: 1) Flag any logical errors, incorrect assumptions, or missed edge cases. 2) Suggest alternative approaches the original model may have overlooked. 3) Identify any security or correctness concerns. 4) Be concise and actionable - only raise genuine issues. If the reasoning is sound, start with \"CONSENSUS:\" and briefly confirm. If you have concerns, start with \"CONCERNS:\" and list them."
            ;;
        esac
    fi

    full_prompt="${review_prompt}

---
Reasoning to review:
${last_response}
---"
    if [ "$VERBOSE" = "2" ]; then
        log_banner "Initial Review"
        log_kv "Mode" "$bridge_mode"
        log_kv "Prompt" "$(echo "$review_prompt" | head -1 | cut -c1-80)..."
    fi
fi

# Pre-filter: remove providers where ALL profiles are already cooled down
# This avoids wasting time on providers we know can't respond
active_providers=()
for _p in "${providers[@]}"; do
    _p="${_p#"${_p%%[![:space:]]*}"}"
    _p="${_p%"${_p##*[![:space:]]}"}"
    if [ "$_p" = "claude" ] && [ -n "${CROSS_PROVIDER_CLAUDE_PROFILES:-}" ] && all_claude_profiles_cooled; then
        log_verbose "Pre-filter: skipping $a_p (all Claude profiles cooled)"
        if [ "$VERBOSE" -ge 1 ]; then
            log_status "${C_YELLOW}⏭${C_RESET}" "${C_BOLD}$_p${C_RESET} ${C_DIM}(all profiles cooled — skipped)${C_RESET}"
        fi
        continue
    elif [ "$_p" = "codex" ] && [ -n "${CROSS_PROVIDER_CODEX_PROFILES:-}" ] && all_codex_profiles_cooled; then
        log_verbose "Pre-filter: skipping $_p (all Codex profiles cooled)"
        if [ "$VERBOSE" -ge 1 ]; then
            log_status "${C_YELLOW}⏭${C_RESET}" "${C_BOLD}$_p${C_RESET} ${C_DIM}(all profiles cooled — skipped)${C_RESET}"
        fi
        continue
    elif is_provider_cooled_down "$_p"; then
        log_verbose "Pre-filter: skipping $_p (cooled down)"
        if [ "$VERBOSE" -ge 1 ]; then
            _rem=$(get_cooldown_remaining "$_p")
            log_status "${C_YELLOW}⏭${C_RESET}" "${C_BOLD}$_p${C_RESET} ${C_DIM}(cooled down, ${_rem}s — skipped)${C_RESET}"
        fi
        continue
    fi
    active_providers+=("$_p")
done

if [ ${#active_providers[@]} -eq 0 ]; then
    log_verbose "All providers are cooled down, allowing stop (silent fallback)"
    if [ "$VERBOSE" -ge 1 ]; then
        log_status "${C_RED}!${C_RESET}" "All providers cooled down — passing through"
    fi
    exit 0
fi

# Try providers in priority order (pre-filtered)
cross_provider_output=""
provider_used=""

log_verbose "Active providers: ${active_providers[*]} (from: ${providers[*]})"

if [ "$VERBOSE" = "2" ]; then
    log_banner "Provider Dispatch"
fi

for provider in "${active_providers[@]}"; do
    provider="${provider#"${provider%%[![:space:]]*}"}" # trim leading
    provider="${provider%"${provider##*[![:space:]]}"}" # trim trailing

    log_verbose "Trying provider: $provider"
    if [ "$VERBOSE" = "2" ]; then
        printf "  ${C_YELLOW}→${C_RESET} ${C_BOLD}%s${C_RESET} " "$provider" >&2
    fi

    # Capture timing
    local_start=$(date +%s)

    # Clear stderr capture
    : >"$PROVIDER_STDERR_FILE" 2>/dev/null

    # Skip if provider is in cooldown
    if [ "$provider" = "claude" ] && [ -n "${CROSS_PROVIDER_CLAUDE_PROFILES:-}" ]; then
        if all_claude_profiles_cooled; then
            log_verbose "Skipping $provider: all profiles cooled down"
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_YELLOW}all profiles cooled${C_RESET}" >&2
            fi
            continue
        fi
    elif [ "$provider" = "codex" ] && [ -n "${CROSS_PROVIDER_CODEX_PROFILES:-}" ]; then
        if all_codex_profiles_cooled; then
            log_verbose "Skipping $provider: all profiles cooled down"
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_YELLOW}all profiles cooled${C_RESET}" >&2
            fi
            continue
        fi
    elif is_provider_cooled_down "$provider"; then
        local_remaining=$(get_cooldown_remaining "$provider")
        log_verbose "Skipping $provider: cooled down (${local_remaining}s remaining)"
        if [ "$VERBOSE" = "2" ]; then
            echo "${C_YELLOW}cooled down${C_RESET} ${C_DIM}(${local_remaining}s)${C_RESET}" >&2
        fi
        continue
    fi

    case "$provider" in
    codex)
        if cross_provider_output=$(provider_codex "$full_prompt"); then
            provider_used=$(get_provider_display_name codex)
            local_end=$(date +%s)
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_GREEN}success${C_RESET} ${C_DIM}($((local_end - local_start))s)${C_RESET}" >&2
            fi
            break
        fi
        ;;
    gemini)
        if cross_provider_output=$(provider_gemini "$full_prompt"); then
            provider_used=$(get_provider_display_name gemini)
            local_end=$(date +%s)
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_GREEN}success${C_RESET} ${C_DIM}($((local_end - local_start))s)${C_RESET}" >&2
            fi
            break
        fi
        ;;
    ollama)
        if cross_provider_output=$(provider_ollama "$full_prompt"); then
            provider_used=$(get_provider_display_name ollama)
            local_end=$(date +%s)
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_GREEN}success${C_RESET} ${C_DIM}($((local_end - local_start))s)${C_RESET}" >&2
            fi
            break
        fi
        ;;
    deepseek)
        if cross_provider_output=$(provider_deepseek "$full_prompt"); then
            provider_used=$(get_provider_display_name deepseek)
            local_end=$(date +%s)
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_GREEN}success${C_RESET} ${C_DIM}($((local_end - local_start))s)${C_RESET}" >&2
            fi
            break
        fi
        ;;
    claude)
        if cross_provider_output=$(provider_claude "$full_prompt"); then
            provider_used=$(get_provider_display_name claude)
            local_end=$(date +%s)
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_GREEN}success${C_RESET} ${C_DIM}($((local_end - local_start))s)${C_RESET}" >&2
            fi
            break
        fi
        ;;
    opencode)
        if cross_provider_output=$(provider_opencode "$full_prompt"); then
            provider_used=$(get_provider_display_name opencode)
            local_end=$(date +%s)
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_GREEN}success${C_RESET} ${C_DIM}($((local_end - local_start))s)${C_RESET}" >&2
            fi
            break
        fi
        ;;
    *)
        log_verbose "Unknown provider: $provider (skipping)"
        if [ "$VERBOSE" = "2" ]; then
            echo "${C_RED}unknown${C_RESET}" >&2
        fi
        continue
        ;;
    esac

    # If we got here, provider failed
    local_end=$(date +%s)

    # Check if failure was rate limiting (profile rotation handles this internally for claude/codex)
    skip_rate_check=false
    if [ "$provider" = "claude" ] && [ -n "${CROSS_PROVIDER_CLAUDE_PROFILES:-}" ]; then skip_rate_check=true; fi
    if [ "$provider" = "codex" ] && [ -n "${CROSS_PROVIDER_CODEX_PROFILES:-}" ]; then skip_rate_check=true; fi
    if [ "$skip_rate_check" = "false" ]; then
        local_stderr=""
        [ -f "$PROVIDER_STDERR_FILE" ] && local_stderr=$(cat "$PROVIDER_STDERR_FILE" 2>/dev/null)
        if detect_rate_limit "" "$local_stderr"; then
            set_provider_cooldown "$provider" "$local_stderr"
            _cd_rem=$(get_cooldown_remaining "$provider")
            log_verbose "Provider $provider: rate limited, setting cooldown (${_cd_rem}s)"
            if [ "$VERBOSE" = "2" ]; then
                echo "${C_RED}rate limited${C_RESET} ${C_DIM}($((local_end - local_start))s, cooling ${_cd_rem}s)${C_RESET}" >&2
            fi
            continue
        fi
    fi

    if [ "$VERBOSE" = "2" ]; then
        echo "${C_RED}failed${C_RESET} ${C_DIM}($((local_end - local_start))s)${C_RESET}" >&2
    fi
done

# No provider succeeded - silently continue with Claude
if [ -z "$cross_provider_output" ]; then
    log_verbose "All providers failed, allowing stop (silent fallback)"
    if [ "$VERBOSE" = "2" ]; then
        echo "" >&2
        log_status "${C_RED}✗${C_RESET}" "All providers failed — allowing stop (silent fallback)"
        echo "" >&2
    fi
    rm -f "$state_file" 2>/dev/null
    exit 0
fi

log_verbose "Provider $provider_used returned ${#cross_provider_output} chars"

# Strip provider CLI metadata (Codex headers, echoed prompt, ANSI codes)
cross_provider_output=$(strip_provider_metadata "$cross_provider_output")
# Strip thinking blocks from any provider (prevents false consensus from heuristic phrases)
cross_provider_output=$(strip_thinking_blocks "$cross_provider_output")

# Log the review if log file configured
if [ -n "$LOG_FILE" ]; then
    {
        echo "--- Review by $provider_used (iteration $((current_iteration + 1))/$max_iterations) [session: ${session_id:-unknown}] ---"
        echo "$cross_provider_output"
        echo "---"
        echo ""
    } >>"$LOG_FILE"
fi

# Check for consensus
if [ "$VERBOSE" = "2" ]; then
    echo "" >&2
    log_banner "Consensus Check"
    log_kv "Provider" "$provider_used"
    log_kv "Response size" "${#cross_provider_output} chars"
    log_kv "First line" "$(echo "$cross_provider_output" | head -1 | cut -c1-80)"
fi

if detect_consensus "$cross_provider_output"; then
    if [ "$VERBOSE" = "2" ]; then
        log_status "${C_GREEN}✓${C_RESET}" "${C_GREEN}Consensus reached${C_RESET} — allowing stop"
        echo "" >&2
    fi
    rm -f "$state_file" 2>/dev/null
    exit 0 # Allow stop — consensus reached
fi

log_verbose "No consensus — blocking for iteration $((current_iteration + 1))/$max_iterations"

if [ "$VERBOSE" = "2" ]; then
    log_status "${C_YELLOW}→${C_RESET}" "${C_YELLOW}No consensus${C_RESET} — blocking for next iteration ($((current_iteration + 1))/$max_iterations)"
    echo "" >&2
fi

# No consensus — save state and block for next iteration
new_iteration=$((current_iteration + 1))
if [ -n "$state_file" ]; then
    if [ -f "$state_file" ]; then
        # Append review to existing state (PID-unique temp file prevents race conditions)
        timeout 5 jq --arg review "$cross_provider_output" \
            --arg provider "$provider_used" \
            --argjson iter "$new_iteration" \
            --argjson ts "$(date +%s)" \
            '.iteration = $iter | .previous_reviews += [$review] | .providers_used += [$provider] | .last_updated = $ts' \
            "$state_file" >"${state_file}.tmp.$$" && mv "${state_file}.tmp.$$" "$state_file"
    else
        # Create new state file
        timeout 5 jq -n --arg review "$cross_provider_output" \
            --arg provider "$provider_used" \
            --argjson iter "$new_iteration" \
            --argjson ts "$(date +%s)" \
            '{iteration: $iter, previous_reviews: [$review], providers_used: [$provider], created_at: $ts, last_updated: $ts}' \
            >"$state_file"
    fi
fi

# Return block decision with cross-provider review and iteration context
# jq handles all JSON escaping safely
jq -n \
    --arg provider "$provider_used" \
    --arg output "$cross_provider_output" \
    --argjson iter "$new_iteration" \
    --argjson max "$max_iterations" \
    '{
        decision: "block",
        reason: ("Cross-provider review (" + $provider + ", iteration " + ($iter|tostring) + "/" + ($max|tostring) + "):\n\n" + $output + "\n\nAddress these concerns and update your response. The reviewer will verify your changes.")
    }'
