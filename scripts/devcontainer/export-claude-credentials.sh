#!/usr/bin/env bash
# export-claude-credentials.sh
# Extracts Claude Code OAuth credentials from macOS Keychain
# and writes them to a file that can be mounted into devcontainers.
#
# This runs on the HOST (macOS) before launching a devcontainer.
# The exported credentials are stored per-instance so each
# devcontainer can pick them up on start.
#
# Usage: export-claude-credentials.sh [instance-name]

set -euo pipefail

INSTANCE_NAME="${1:-default}"
KEYCHAIN_SERVICE="Claude Code-credentials"
EXPORT_DIR="${HOME}/.devcontainer/instances/${INSTANCE_NAME}/env"

# Ensure export directory exists
mkdir -p "${EXPORT_DIR}"

EXPORT_FILE="${EXPORT_DIR}/.claude-credentials.json"

# Try to extract from macOS Keychain
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Skipping credential export (not macOS)"
    exit 0
fi

CREDS=$(security find-generic-password -a "$USER" -w -s "${KEYCHAIN_SERVICE}" 2>/dev/null || true)

if [[ -z "${CREDS}" ]]; then
    echo "No Claude Code credentials found in Keychain."
    echo "Run 'claude login' on the host first."
    exit 0
fi

# Validate it's valid JSON before writing
if ! echo "${CREDS}" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    echo "Warning: Keychain credentials are not valid JSON, skipping export"
    exit 1
fi

# Write credentials with restrictive permissions
umask 077
echo "${CREDS}" > "${EXPORT_FILE}"
chmod 600 "${EXPORT_FILE}"

echo "Claude Code credentials exported for instance: ${INSTANCE_NAME}"
