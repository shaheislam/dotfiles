#!/usr/bin/env bash
#
# checkpoint-commit-msg.sh - prepare-commit-msg git hook
#
# Adds a Checkpoint trailer to the commit message if a pending
# checkpoint exists. Called by git during commit.
#
# Args: $1 = commit message file, $2 = source, $3 = SHA (amend)

set -euo pipefail

COMMIT_MSG_FILE="${1:-}"
PENDING_DIR=".checkpoints"

if [[ -z "$COMMIT_MSG_FILE" ]]; then
    exit 0
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)

# Find any pending checkpoint
pending=$(find "${root}/${PENDING_DIR}" -name 'pending.json' -type f 2>/dev/null | head -1 || true)

if [[ -z "$pending" || ! -f "$pending" ]]; then
    exit 0
fi

# Generate checkpoint ID: first 12 chars of SHA256(session_id + timestamp)
session_id=$(jq -r '.session_id // "unknown"' "$pending" 2>/dev/null)
timestamp=$(jq -r '.timestamp // ""' "$pending" 2>/dev/null)
checkpoint_id=$(echo -n "${session_id}${timestamp}" | shasum -a 256 | head -c 12)

# Append trailer to commit message (after blank line if not already present)
if ! grep -q "^Checkpoint:" "$COMMIT_MSG_FILE" 2>/dev/null; then
    echo "" >> "$COMMIT_MSG_FILE"
    echo "Checkpoint: ${checkpoint_id}" >> "$COMMIT_MSG_FILE"
fi
