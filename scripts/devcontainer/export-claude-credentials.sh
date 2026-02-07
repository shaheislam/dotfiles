#!/usr/bin/env bash
# export-claude-credentials.sh
# Extracts Claude Code OAuth credentials from macOS Keychain
# and writes them to the shared .claude directory used by all devcontainers.
#
# This runs on the HOST (macOS) before launching a devcontainer.
# Credentials are written to ~/.devcontainer/shared/.claude/.credentials.json
# which is bind-mounted into every container.
#
# Usage: export-claude-credentials.sh [--force]

set -euo pipefail

KEYCHAIN_SERVICE="Claude Code-credentials"
SHARED_DIR="${HOME}/.devcontainer/shared/.claude"
EXPORT_FILE="${SHARED_DIR}/.credentials.json"
FORCE=false

for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
    esac
done

# Only runs on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Skipping credential export (not macOS)"
    exit 0
fi

# Ensure shared directory exists with correct permissions
mkdir -p "${SHARED_DIR}"
chmod 700 "${SHARED_DIR}"

# Skip if valid credentials already exist (unless --force)
if [[ -f "${EXPORT_FILE}" ]] && ! $FORCE; then
    if python3 -c "import sys,json; json.load(open('${EXPORT_FILE}'))" 2>/dev/null; then
        echo "Credentials already exist at ${EXPORT_FILE} (use --force to overwrite)"
        exit 0
    fi
fi

# Extract from macOS Keychain
CREDS=$(security find-generic-password -a "$USER" -w -s "${KEYCHAIN_SERVICE}" 2>/dev/null || true)

if [[ -z "${CREDS}" ]]; then
    echo "No Claude Code credentials found in Keychain."
    echo "Run 'claude login' on the host first."
    exit 1
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

echo "Claude Code credentials exported to shared directory"
