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
#   CROSS_PROVIDER_VERBOSE=1                    Verbose logging to stderr
#   CROSS_PROVIDER_MAX_CHARS=4000               Max context chars to send
#   CROSS_PROVIDER_PROMPT=                      Custom review prompt
#   CROSS_PROVIDER_MAX_ITERATIONS=3             Max consensus iterations (1=single-shot)
#   CROSS_PROVIDER_TIMEOUT=120                  Per-provider timeout in seconds
#   CROSS_PROVIDER_LOG=                         Log file path for review history
#
#   Provider-specific model overrides:
#   CROSS_PROVIDER_CODEX_MODEL=                 Codex model override
#   CROSS_PROVIDER_GEMINI_MODEL=                Gemini model (default: CLI default)
#   CROSS_PROVIDER_OLLAMA_MODEL=qwen3-coder     Ollama model for direct use
#   CROSS_PROVIDER_DEEPSEEK_MODEL=deepseek-r1   DeepSeek model (via Ollama)
#   CROSS_PROVIDER_CLAUDE_MODEL=sonnet           Claude model for cross-review
#   CROSS_PROVIDER_OPENCODE_MODEL=ollama/qwen3-coder  OpenCode model
set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Gate: bridge must be explicitly enabled
if [ "${CROSS_PROVIDER_BRIDGE:-}" != "1" ]; then
    exit 0
fi

# --- Verbose logging ---
VERBOSE="${CROSS_PROVIDER_VERBOSE:-0}"
LOG_FILE="${CROSS_PROVIDER_LOG:-}"

log_verbose() {
    if [ "$VERBOSE" = "1" ]; then
        echo "[bridge] $*" >&2
    fi
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
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
} < <(echo "$INPUT" | jq -r '
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
    created_at=$(jq -r '.created_at // 0' "$state_file" 2>/dev/null)
    now=$(date +%s)
    if [ $((now - created_at)) -gt 600 ]; then
        log_verbose "State file stale (>10min), cleaning up"
        rm -f "$state_file"
        exit 0
    fi
    # Max iterations check
    current_iteration=$(jq -r '.iteration // 0' "$state_file" 2>/dev/null)
    if [ "$current_iteration" -ge "$max_iterations" ]; then
        log_verbose "Max iterations reached ($current_iteration/$max_iterations), allowing stop"
        rm -f "$state_file"
        exit 0
    fi
    # Load previous review for follow-up prompt
    previous_review=$(jq -r '.previous_reviews[-1] // empty' "$state_file" 2>/dev/null)
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

# Consensus detection: check if reviewer output indicates agreement
detect_consensus() {
    local output="$1"
    local first_line
    first_line=$(echo "$output" | head -1)
    # Primary: keyword prefix (case-insensitive)
    if echo "$first_line" | grep -qi '^CONSENSUS:'; then
        return 0
    fi
    # Skip heuristic if reviewer explicitly flagged concerns
    if echo "$first_line" | grep -qi '^CONCERNS:'; then
        return 1
    fi
    # Heuristic fallback (only when no explicit prefix)
    if echo "$output" | grep -qi \
        -e 'all concerns addressed' \
        -e 'no remaining issues' \
        -e 'no further concerns' \
        -e 'reasoning is sound' \
        -e 'adequately addressed'; then
        return 0
    fi
    return 1
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
    local codex_cmd=(codex exec)
    if [ -n "${CROSS_PROVIDER_CODEX_MODEL:-}" ]; then
        codex_cmd+=(--model "${CROSS_PROVIDER_CODEX_MODEL}")
    fi
    log_verbose "Provider codex: running ${codex_cmd[*]}"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" "${codex_cmd[@]}" - 2>/dev/null) || true
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
    if [ -n "${CROSS_PROVIDER_GEMINI_MODEL:-}" ]; then
        gemini_cmd+=(--model "${CROSS_PROVIDER_GEMINI_MODEL}")
    fi
    log_verbose "Provider gemini: running ${gemini_cmd[*]}"
    local output
    # Gemini CLI: positional prompt for non-interactive one-shot mode
    output=$(timeout "$provider_timeout" "${gemini_cmd[@]}" "$prompt" 2>/dev/null) || true
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
    local model="${CROSS_PROVIDER_OLLAMA_MODEL:-qwen3-coder}"
    log_verbose "Provider ollama: running model=$model"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" ollama run "$model" 2>/dev/null) || true
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
    local model="${CROSS_PROVIDER_DEEPSEEK_MODEL:-deepseek-r1}"
    log_verbose "Provider deepseek: running model=$model via ollama"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" ollama run "$model" 2>/dev/null) || true
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
    local model="${CROSS_PROVIDER_CLAUDE_MODEL:-sonnet}"
    log_verbose "Provider claude: running model=$model"
    local output
    output=$(echo "$prompt" | timeout "$provider_timeout" claude -p --model "$model" 2>/dev/null) || true
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
    local oc_model="${CROSS_PROVIDER_OPENCODE_MODEL:-ollama/qwen3-coder}"
    log_verbose "Provider opencode: running model=$oc_model"
    local output
    output=$(timeout "$provider_timeout" opencode run --model "$oc_model" "$prompt" 2>/dev/null) || true
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
# JSONL messages are single lines, so tail -100 is generous for finding the last assistant turn
last_response=$(tail -100 "$transcript_path" | jq -rs '
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
else
    # Initial review prompt
    if [ -n "${CROSS_PROVIDER_PROMPT:-}" ]; then
        review_prompt="$CROSS_PROVIDER_PROMPT"
    else
        review_prompt="You are an independent AI reviewer checking another AI model's work for correlation bias. Review the reasoning below and: 1) Flag any logical errors, incorrect assumptions, or missed edge cases. 2) Suggest alternative approaches the original model may have overlooked. 3) Identify any security or correctness concerns. 4) Be concise and actionable - only raise genuine issues. If the reasoning is sound, start with \"CONSENSUS:\" and briefly confirm. If you have concerns, start with \"CONCERNS:\" and list them."
    fi

    full_prompt="${review_prompt}

---
Reasoning to review:
${last_response}
---"
fi

# Try providers in priority order
IFS=',' read -ra providers <<< "${CROSS_PROVIDER_ORDER:-codex,opencode}"

cross_provider_output=""
provider_used=""

log_verbose "Provider order: ${providers[*]}"

for provider in "${providers[@]}"; do
    provider=$(echo "$provider" | xargs)  # trim whitespace

    log_verbose "Trying provider: $provider"

    case "$provider" in
        codex)
            if cross_provider_output=$(provider_codex "$full_prompt"); then
                provider_used="Codex"
                break
            fi
            ;;
        gemini)
            if cross_provider_output=$(provider_gemini "$full_prompt"); then
                provider_used="Gemini"
                break
            fi
            ;;
        ollama)
            if cross_provider_output=$(provider_ollama "$full_prompt"); then
                local_model="${CROSS_PROVIDER_OLLAMA_MODEL:-qwen3-coder}"
                provider_used="Ollama ($local_model)"
                break
            fi
            ;;
        deepseek)
            if cross_provider_output=$(provider_deepseek "$full_prompt"); then
                local_model="${CROSS_PROVIDER_DEEPSEEK_MODEL:-deepseek-r1}"
                provider_used="DeepSeek ($local_model)"
                break
            fi
            ;;
        claude)
            if cross_provider_output=$(provider_claude "$full_prompt"); then
                local_model="${CROSS_PROVIDER_CLAUDE_MODEL:-sonnet}"
                provider_used="Claude ($local_model)"
                break
            fi
            ;;
        opencode)
            if cross_provider_output=$(provider_opencode "$full_prompt"); then
                local_model="${CROSS_PROVIDER_OPENCODE_MODEL:-ollama/qwen3-coder}"
                provider_used="OpenCode ($local_model)"
                break
            fi
            ;;
        *)
            log_verbose "Unknown provider: $provider (skipping)"
            continue
            ;;
    esac
done

# No provider succeeded - silently continue with Claude
if [ -z "$cross_provider_output" ]; then
    log_verbose "All providers failed, allowing stop (silent fallback)"
    rm -f "$state_file" 2>/dev/null
    exit 0
fi

log_verbose "Provider $provider_used returned ${#cross_provider_output} chars"

# Strip provider CLI metadata (Codex headers, echoed prompt, thinking blocks, ANSI codes)
cross_provider_output=$(strip_provider_metadata "$cross_provider_output")

# Log the review if log file configured
if [ -n "$LOG_FILE" ]; then
    {
        echo "--- Review by $provider_used (iteration $((current_iteration + 1))/$max_iterations) ---"
        echo "$cross_provider_output"
        echo "---"
        echo ""
    } >> "$LOG_FILE"
fi

# Check for consensus
if detect_consensus "$cross_provider_output"; then
    log_verbose "Consensus reached by $provider_used"
    rm -f "$state_file" 2>/dev/null
    exit 0  # Allow stop — consensus reached
fi

log_verbose "No consensus — blocking for iteration $((current_iteration + 1))/$max_iterations"

# No consensus — save state and block for next iteration
new_iteration=$((current_iteration + 1))
if [ -n "$state_file" ]; then
    if [ -f "$state_file" ]; then
        # Append review to existing state
        jq --arg review "$cross_provider_output" \
           --arg provider "$provider_used" \
           --argjson iter "$new_iteration" \
           --argjson ts "$(date +%s)" \
           '.iteration = $iter | .previous_reviews += [$review] | .providers_used += [$provider] | .last_updated = $ts' \
           "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
    else
        # Create new state file
        jq -n --arg review "$cross_provider_output" \
              --arg provider "$provider_used" \
              --argjson iter "$new_iteration" \
              --argjson ts "$(date +%s)" \
              '{iteration: $iter, previous_reviews: [$review], providers_used: [$provider], created_at: $ts, last_updated: $ts}' \
              > "$state_file"
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
