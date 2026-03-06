#!/usr/bin/env bash
#
# static-analysis-context.sh - PostToolUse hook for Edit/Write
#
# After an AI agent edits or creates a file, run lightweight static analysis
# and inject findings into the agent's context. This creates a feedback loop
# where the agent can immediately see and fix issues it introduced.
#
# Integration: PostToolUse (Edit|Write) in .claude/settings.json
#
# Environment (provided by Claude Code hooks):
#   TOOL_INPUT  - JSON with tool parameters (file_path, etc.)
#   TOOL_OUTPUT - JSON with tool result
#
# Output: Prints findings to stdout (injected as system context)
#
# Safety features:
#   - Debounce: skips if same file analyzed within DEBOUNCE_SECS (default 3s)
#   - Lockfile: prevents concurrent runs via mkdir atomicity
#   - Redaction: strips absolute paths to project-relative paths
#   - Severity gate: only surfaces warning+ by default (configurable)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
GATEWAY_SCRIPT="$PROJECT_DIR/scripts/aigateway/analyze.sh"

# Configuration (override via environment)
DEBOUNCE_SECS="${AIGATEWAY_DEBOUNCE_SECS:-3}"
MIN_SEVERITY="${AIGATEWAY_MIN_SEVERITY:-warning}"
LOCK_DIR="/tmp/aigateway-hooks"
mkdir -p "$LOCK_DIR"

# Extract the file path from tool input
FILE_PATH=""
if [[ -n "${TOOL_INPUT:-}" ]]; then
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null || true)
fi

# Bail if no file or gateway script missing
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    exit 0
fi

if [[ ! -x "$GATEWAY_SCRIPT" ]]; then
    exit 0
fi

# ─── Debounce: skip if same file analyzed recently ────────
# Uses file mtime of a marker to track last analysis time
MARKER_FILE="$LOCK_DIR/$(echo "$FILE_PATH" | sed 's|/|_|g').marker"
if [[ -f "$MARKER_FILE" ]]; then
    MARKER_AGE=$(($(date +%s) - $(stat -f '%m' "$MARKER_FILE" 2>/dev/null || echo 0)))
    if [[ "$MARKER_AGE" -lt "$DEBOUNCE_SECS" ]]; then
        exit 0
    fi
fi

# ─── Lockfile: prevent concurrent analysis of same file ───
# Uses mkdir atomicity (portable across macOS/Linux, no flock needed)
LOCK_DIR_FILE="$LOCK_DIR/$(echo "$FILE_PATH" | sed 's|/|_|g').lock.d"
if ! mkdir "$LOCK_DIR_FILE" 2>/dev/null; then
    # Check for stale lock (older than 30s = analysis hung or crashed)
    if [[ -d "$LOCK_DIR_FILE" ]]; then
        LOCK_AGE=$(($(date +%s) - $(stat -f '%m' "$LOCK_DIR_FILE" 2>/dev/null || echo 0)))
        if [[ "$LOCK_AGE" -gt 30 ]]; then
            rmdir "$LOCK_DIR_FILE" 2>/dev/null || true
            mkdir "$LOCK_DIR_FILE" 2>/dev/null || exit 0
        else
            exit 0 # Another analysis is running for this file
        fi
    fi
fi
# Clean up lock on exit
trap 'rmdir "$LOCK_DIR_FILE" 2>/dev/null || true' EXIT

# Update debounce marker
touch "$MARKER_FILE"

# Only analyze files we have tools for
case "$FILE_PATH" in
*.sh | *.bash | *.py | *.pyi | *.ts | *.tsx | *.js | *.jsx | *.go) ;;
*)
    # Check shebang for extensionless files
    if ! head -1 "$FILE_PATH" 2>/dev/null | grep -qE '^#!.*\b(bash|sh|python)\b'; then
        exit 0
    fi
    ;;
esac

# Select the fastest tool for the file type
# Skip semgrep in hook context — it has multi-second startup cost
TOOL_ARG=""
case "$FILE_PATH" in
*.sh | *.bash) TOOL_ARG="--tool shellcheck" ;;
*.py | *.pyi) TOOL_ARG="--tool ruff" ;;
*) exit 0 ;; # Skip for languages without fast single-file linters
esac

OUTPUT=$("$GATEWAY_SCRIPT" $TOOL_ARG --severity "$MIN_SEVERITY" --agent-context "$FILE_PATH" 2>/dev/null || true)

# Only inject if there are actual findings (not just "no issues found")
if [[ -z "$OUTPUT" || "$OUTPUT" == *"no issues found"* ]]; then
    exit 0
fi

# ─── Redact absolute paths to project-relative ────────────
# Prevents leaking full filesystem paths into agent context
if [[ -n "$PROJECT_DIR" && "$PROJECT_DIR" != "." ]]; then
    OUTPUT=$(echo "$OUTPUT" | sed "s|$PROJECT_DIR/||g")
fi

echo "$OUTPUT"
exit 0
