#!/usr/bin/env bash
# Cross-Provider Reasoning Bridge - Stop Hook for Claude Code
#
# Sends Claude's reasoning to an independent AI provider (Codex/OpenCode)
# for cross-provider validation with iterative consensus. The reviewer and
# Claude exchange feedback until consensus is reached or max iterations hit.
#
# Graceful fallback: Codex → OpenCode → silent continue (zero failures)
#
# Environment variables:
#   CROSS_PROVIDER_BRIDGE=1                Enable the bridge (default: disabled)
#   CROSS_PROVIDER_ORDER=codex,opencode    Provider priority order
#   CROSS_PROVIDER_CODEX_MODEL=            Codex model override
#   CROSS_PROVIDER_OPENCODE_MODEL=         OpenCode model (default: ollama/qwen3-coder)
#   CROSS_PROVIDER_MAX_CHARS=4000          Max context chars to send
#   CROSS_PROVIDER_PROMPT=                 Custom review prompt
#   CROSS_PROVIDER_MAX_ITERATIONS=3        Max consensus iterations (default: 3, set 1 for single-shot)
set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Gate: bridge must be explicitly enabled
if [ "${CROSS_PROVIDER_BRIDGE:-}" != "1" ]; then
    exit 0
fi

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

max_iterations="${CROSS_PROVIDER_MAX_ITERATIONS:-3}"
state_file=""
current_iteration=0
previous_review=""

if [ -n "$session_id" ]; then
    state_file="/tmp/cross-provider-bridge-${session_id}.json"
fi

if [ "$stop_hook_active" = "true" ]; then
    # No state file or no session_id → safety exit (backward compat)
    if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
        exit 0
    fi
    # Stale check (>10 min — shorter window for faster crash recovery)
    created_at=$(jq -r '.created_at // 0' "$state_file" 2>/dev/null)
    now=$(date +%s)
    if [ $((now - created_at)) -gt 600 ]; then
        rm -f "$state_file"
        exit 0
    fi
    # Max iterations check
    current_iteration=$(jq -r '.iteration // 0' "$state_file" 2>/dev/null)
    if [ "$current_iteration" -ge "$max_iterations" ]; then
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

# Validate transcript path (already parsed from input above)
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
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
    exit 0
fi

# Truncate to reasonable size
max_chars="${CROSS_PROVIDER_MAX_CHARS:-4000}"
last_response="${last_response:0:$max_chars}"

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

for provider in "${providers[@]}"; do
    provider=$(echo "$provider" | xargs)  # trim whitespace

    case "$provider" in
        codex)
            if ! command -v codex &>/dev/null; then
                continue
            fi
            # Codex supports both API key and subscription (ChatGPT) auth
            # No key check needed — let codex exec fail naturally if unauthed

            codex_cmd=(codex exec)
            if [ -n "${CROSS_PROVIDER_CODEX_MODEL:-}" ]; then
                codex_cmd+=(--model "${CROSS_PROVIDER_CODEX_MODEL}")
            fi
            # codex exec - reads prompt from stdin
            cross_provider_output=$(echo "$full_prompt" | timeout 120 "${codex_cmd[@]}" - 2>/dev/null) || true
            if [ -n "$cross_provider_output" ]; then
                provider_used="Codex"
                break
            fi
            ;;

        opencode)
            if ! command -v opencode &>/dev/null; then
                continue
            fi
            oc_model="${CROSS_PROVIDER_OPENCODE_MODEL:-ollama/qwen3-coder}"
            # opencode run: positional message args, no -q flag exists
            cross_provider_output=$(timeout 120 opencode run --model "$oc_model" "$full_prompt" 2>/dev/null) || true
            if [ -n "$cross_provider_output" ]; then
                provider_used="OpenCode ($oc_model)"
                break
            fi
            ;;

        *)
            continue
            ;;
    esac
done

# No provider succeeded - silently continue with Claude
if [ -z "$cross_provider_output" ]; then
    rm -f "$state_file" 2>/dev/null
    exit 0
fi

# Strip provider CLI metadata (Codex headers, echoed prompt, thinking blocks)
cross_provider_output=$(strip_provider_metadata "$cross_provider_output")

# Check for consensus
if detect_consensus "$cross_provider_output"; then
    rm -f "$state_file" 2>/dev/null
    exit 0  # Allow stop — consensus reached
fi

# No consensus — save state and block for next iteration
new_iteration=$((current_iteration + 1))
if [ -n "$state_file" ]; then
    if [ -f "$state_file" ]; then
        # Append review to existing state
        jq --arg review "$cross_provider_output" \
           --argjson iter "$new_iteration" \
           --argjson ts "$(date +%s)" \
           '.iteration = $iter | .previous_reviews += [$review] | .last_updated = $ts' \
           "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
    else
        # Create new state file
        jq -n --arg review "$cross_provider_output" \
              --argjson iter "$new_iteration" \
              --argjson ts "$(date +%s)" \
              '{iteration: $iter, previous_reviews: [$review], created_at: $ts, last_updated: $ts}' \
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
