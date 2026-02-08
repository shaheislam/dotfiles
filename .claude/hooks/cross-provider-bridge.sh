#!/usr/bin/env bash
# Cross-Provider Reasoning Bridge - Stop Hook for Claude Code
#
# Sends Claude's reasoning to an independent AI provider (Codex/OpenCode)
# for cross-provider validation, then feeds the review back to Claude.
#
# Graceful fallback: Codex → OpenCode → silent continue (zero failures)
#
# Environment variables:
#   CROSS_PROVIDER_BRIDGE=1                Enable the bridge (default: disabled)
#   CROSS_PROVIDER_ORDER=codex,opencode    Provider priority order
#   CROSS_PROVIDER_CODEX_MODEL=            Codex model override
#   CROSS_PROVIDER_OPENCODE_MODEL=         OpenCode model (default: openai/gpt-4o)
#   CROSS_PROVIDER_MAX_CHARS=4000          Max context chars to send
#   CROSS_PROVIDER_PROMPT=                 Custom review prompt
set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Gate: bridge must be explicitly enabled
if [ "${CROSS_PROVIDER_BRIDGE:-}" != "1" ]; then
    exit 0
fi

# Gate: prevent infinite loops (stop_hook_active = already continuing from hook)
stop_hook_active=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$stop_hook_active" = "true" ]; then
    exit 0
fi

# Extract transcript path from hook input
transcript_path=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    exit 0
fi

# Extract last assistant message from JSONL transcript
# Handles multiple possible formats robustly
last_response=$(jq -rs '
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
' "$transcript_path" 2>/dev/null) || true

if [ -z "$last_response" ]; then
    exit 0
fi

# Truncate to reasonable size
max_chars="${CROSS_PROVIDER_MAX_CHARS:-4000}"
last_response="${last_response:0:$max_chars}"

# Build review prompt
if [ -n "${CROSS_PROVIDER_PROMPT:-}" ]; then
    review_prompt="$CROSS_PROVIDER_PROMPT"
else
    review_prompt="You are an independent AI reviewer checking another AI model's work for correlation bias. Review the reasoning below and: 1) Flag any logical errors, incorrect assumptions, or missed edge cases. 2) Suggest alternative approaches the original model may have overlooked. 3) Identify any security or correctness concerns. 4) Be concise and actionable - only raise genuine issues. If the reasoning is sound, briefly confirm and suggest minor improvements."
fi

full_prompt="${review_prompt}

---
Reasoning to review:
${last_response}
---"

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
            # Codex needs CODEX_API_KEY or OPENAI_API_KEY
            if [ -z "${CODEX_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
                continue
            fi

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
            oc_model="${CROSS_PROVIDER_OPENCODE_MODEL:-openai/gpt-4o}"
            # opencode run: non-interactive mode, -q suppresses spinner
            cross_provider_output=$(timeout 120 opencode run -q --model "$oc_model" "$full_prompt" 2>/dev/null) || true
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
    exit 0
fi

# Return block decision with cross-provider review as reason
# jq handles all JSON escaping safely
jq -n \
    --arg provider "$provider_used" \
    --arg output "$cross_provider_output" \
    '{
        decision: "block",
        reason: ("Cross-provider review (" + $provider + "):\n\n" + $output + "\n\nConsider this independent review and address any valid concerns before completing your response.")
    }'
