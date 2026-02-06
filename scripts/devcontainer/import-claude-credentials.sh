#!/usr/bin/env bash
# import-claude-credentials.sh
# Imports Claude Code credentials into the container's config directory.
#
# This runs INSIDE the devcontainer on start (postStartCommand).
# It reads credentials from the mounted env directory and writes
# them to the Claude config dir as .credentials.json (the plaintext
# fallback that Claude Code uses on Linux).
#
# Usage: import-claude-credentials.sh

set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
SOURCE_FILE="/devcontainer/env/.claude-credentials.json"
TARGET_FILE="${CLAUDE_DIR}/.credentials.json"

# Check if source credentials exist
if [[ ! -f "${SOURCE_FILE}" ]]; then
    echo "No Claude credentials found at ${SOURCE_FILE}"
    echo "Run 'export-claude-credentials.sh' on the host, or 'claude login' inside the container"
    exit 0
fi

# Validate JSON
if ! python3 -c "import sys,json; json.load(open('${SOURCE_FILE}'))" 2>/dev/null; then
    echo "Warning: Credential file is not valid JSON, skipping import"
    exit 1
fi

# Ensure target directory exists
mkdir -p "${CLAUDE_DIR}"

# Copy credentials (don't symlink - the volume mount would break it)
cp "${SOURCE_FILE}" "${TARGET_FILE}"
chmod 600 "${TARGET_FILE}"

echo "Claude Code credentials imported successfully"
