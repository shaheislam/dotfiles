#!/usr/bin/env bash
#
# checkpoint-post-commit.sh - post-commit git hook
#
# After a commit, takes the pending checkpoint data and stores it
# on the checkpoints/v1 orphan branch, sharded by commit SHA.
# Uses git plumbing (temp index) to avoid disturbing the working tree.

set -euo pipefail

PENDING_DIR=".checkpoints"
CHECKPOINT_BRANCH="checkpoints/v1"

root=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
config="${root}/${PENDING_DIR}/config.json"

if [[ ! -f "$config" ]]; then
    exit 0
fi

# Find pending checkpoint
pending_dir=""
pending_json=""
for d in "${root}/${PENDING_DIR}"/*/; do
    if [[ -f "${d}pending.json" ]]; then
        pending_dir="$d"
        pending_json="${d}pending.json"
        break
    fi
done

if [[ -z "$pending_json" || ! -f "$pending_json" ]]; then
    exit 0
fi

# Get the commit SHA that was just made
commit_sha=$(git rev-parse HEAD 2>/dev/null)
if [[ -z "$commit_sha" ]]; then
    exit 0
fi

# Read pending data
session_id=$(jq -r '.session_id // "unknown"' "$pending_json" 2>/dev/null)

# Update metadata with actual commit SHA
metadata=$(jq --arg sha "$commit_sha" '. + {commit_sha: $sha}' "$pending_json" 2>/dev/null)

# Shard path: first 2 chars / next 6 chars
shard="${commit_sha:0:2}/${commit_sha:2:6}"

# Create blob objects
meta_blob=$(echo "$metadata" | git hash-object -w --stdin)

transcript_blob=""
if [[ -f "${pending_dir}transcript.jsonl" ]]; then
    transcript_blob=$(git hash-object -w "${pending_dir}transcript.jsonl")
fi

prompt_blob=""
if [[ -f "${pending_dir}prompt.txt" ]]; then
    prompt_blob=$(git hash-object -w "${pending_dir}prompt.txt")
fi

# Use a temporary index to build the tree without disturbing working tree
tmp_index=$(mktemp)
export GIT_INDEX_FILE="$tmp_index"
cleanup() { rm -f "$tmp_index"; }
trap cleanup EXIT

# Start from existing checkpoint tree if present
if git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
    git read-tree "${CHECKPOINT_BRANCH}" 2>/dev/null || true
fi

# Add checkpoint files to the index at the sharded path
git update-index --add --cacheinfo "100644,${meta_blob},${shard}/metadata.json"

if [[ -n "$transcript_blob" ]]; then
    git update-index --add --cacheinfo "100644,${transcript_blob},${shard}/sessions/${session_id}/transcript.jsonl"
fi
if [[ -n "$prompt_blob" ]]; then
    git update-index --add --cacheinfo "100644,${prompt_blob},${shard}/sessions/${session_id}/prompt.txt"
fi

# Write the tree
new_tree=$(git write-tree)

# Create commit on orphan branch
parent_arg=""
if git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
    parent_sha=$(git rev-parse "${CHECKPOINT_BRANCH}")
    parent_arg="-p ${parent_sha}"
fi

branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
new_commit=$(echo "checkpoint: ${branch_name} ${commit_sha:0:12}" | git commit-tree "$new_tree" $parent_arg)
git update-ref "refs/heads/${CHECKPOINT_BRANCH}" "$new_commit"

# Clean up pending checkpoint
rm -rf "$pending_dir"
