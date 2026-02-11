#!/usr/bin/env bash
#
# checkpoint-pre-push.sh - pre-push git hook
#
# Pushes the checkpoints/v1 branch alongside code when user pushes.

set -euo pipefail

CHECKPOINT_BRANCH="checkpoints/v1"

# Only push if the checkpoint branch exists and has a remote
if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
    exit 0
fi

# Get the remote being pushed to (first arg to pre-push hook)
remote="${1:-origin}"

# Push checkpoint branch (non-blocking, best-effort)
git push "$remote" "${CHECKPOINT_BRANCH}" --no-verify 2>/dev/null &
