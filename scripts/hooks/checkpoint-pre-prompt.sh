#!/usr/bin/env bash
#
# checkpoint-pre-prompt.sh - UserPromptSubmit hook
#
# Captures pre-prompt state: transcript offset, untracked files, timestamp.
# Called by Claude Code before each user prompt is processed.

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

# Find active Claude session JSONL
claude_projects="${HOME}/.claude/projects"
hash_name="-$(echo "$root" | sed 's|^/||; s|/|-|g')"
project_dir="${claude_projects}/${hash_name}"

session_file=""
if [[ -d "$project_dir" ]]; then
    session_file=$(find "$project_dir" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null \
        | head -1 || true)
fi

# Count current transcript lines (offset for later slicing)
transcript_offset=0
if [[ -n "$session_file" && -f "$session_file" ]]; then
    transcript_offset=$(wc -l < "$session_file" | tr -d ' ')
fi

# Capture untracked files at this point
untracked=$(cd "$root" && git ls-files --others --exclude-standard 2>/dev/null | head -100 || true)

# Write pre-prompt state
mkdir -p "${root}/${PENDING_DIR}"
cat > "${root}/${PENDING_DIR}/pre-prompt-state.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "transcript_offset": ${transcript_offset},
  "session_file": "$(echo "$session_file" | sed 's/"/\\"/g')",
  "untracked_files": $(echo "$untracked" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')
}
EOF
