#!/usr/bin/env bash
#
# checkpoint-capture.sh - Stop hook
#
# Captures session context when the agent stops:
# - Reads session JSONL from pre-prompt offset to current end
# - Extracts user prompts, tool calls, files modified
# - Estimates token usage
# - Writes pending checkpoint for the next commit

set -euo pipefail

PENDING_DIR=".checkpoints"

# Only run if checkpoints are enabled in this repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
config="${root}/${PENDING_DIR}/config.json"

if [[ ! -f "$config" ]]; then
    exit 0
fi

pre_state="${root}/${PENDING_DIR}/pre-prompt-state.json"
if [[ ! -f "$pre_state" ]]; then
    exit 0
fi

# Read pre-prompt state
transcript_offset=$(jq -r '.transcript_offset // 0' "$pre_state" 2>/dev/null)
session_file=$(jq -r '.session_file // ""' "$pre_state" 2>/dev/null)
pre_untracked=$(jq -r '.untracked_files // []' "$pre_state" 2>/dev/null)

if [[ -z "$session_file" || ! -f "$session_file" ]]; then
    exit 0
fi

session_id=$(basename "$session_file" .jsonl)

# Extract transcript slice (lines after the offset)
transcript_slice=$(tail -n +"$((transcript_offset + 1))" "$session_file" 2>/dev/null || true)

if [[ -z "$transcript_slice" ]]; then
    # No new transcript lines since pre-prompt — nothing to checkpoint
    exit 0
fi

# Extract user prompts from the transcript slice (handle string and array content)
user_prompts=$(echo "$transcript_slice" \
    | jq -r 'select(.type == "human") | .message.content | if type == "string" then . elif type == "array" then map(select(.type == "text") | .text) | join(" ") else empty end' 2>/dev/null \
    | head -50 || true)

# Extract tool calls (name + file paths)
tool_calls=$(echo "$transcript_slice" \
    | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null \
    | sort | uniq -c | sort -rn \
    | head -20 || true)

# Files modified since pre-prompt
files_modified=$(cd "$root" && git diff --name-only 2>/dev/null || true)
new_untracked=$(cd "$root" && git ls-files --others --exclude-standard 2>/dev/null | head -100 || true)

# Estimate tokens (rough: ~4 chars per token)
char_count=${#transcript_slice}
token_estimate=$((char_count / 4))

# Generate summary: the user's prompt (the "why" behind the commit)
summary=$(echo "$user_prompts" | grep '.' | head -1)
summary="${summary:-"Agent session checkpoint"}"

# Write pending checkpoint
pending_dir="${root}/${PENDING_DIR}/${session_id}"
mkdir -p "$pending_dir"

# Metadata
cat > "${pending_dir}/pending.json" <<EOF
{
  "session_id": "${session_id}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
  "token_estimate": ${token_estimate},
  "transcript_lines": $(echo "$transcript_slice" | wc -l | tr -d ' '),
  "files_modified": $(echo "$files_modified" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'),
  "new_files": $(echo "$new_untracked" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'),
  "tool_calls_summary": $(echo "$tool_calls" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'),
  "summary": $(echo "$summary" | jq -R '.' 2>/dev/null || echo '"checkpoint"')
}
EOF

# Transcript slice
echo "$transcript_slice" > "${pending_dir}/transcript.jsonl"

# User prompts
echo "$user_prompts" > "${pending_dir}/prompt.txt"
