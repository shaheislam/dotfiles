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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY_SCRIPT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}/scripts/aigateway/analyze.sh"

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

# Run analysis with agent-context format, only on the specific file
# Use --tool shellcheck for shell files (fast), ruff for python (fast)
# Skip semgrep in hook context (too slow for real-time feedback)
TOOL_ARG=""
case "$FILE_PATH" in
*.sh | *.bash) TOOL_ARG="--tool shellcheck" ;;
*.py | *.pyi) TOOL_ARG="--tool ruff" ;;
*) exit 0 ;; # Skip for languages without fast linters
esac

OUTPUT=$("$GATEWAY_SCRIPT" $TOOL_ARG --agent-context "$FILE_PATH" 2>/dev/null || true)

# Only inject if there are actual findings (not just "no issues found")
if [[ -n "$OUTPUT" && "$OUTPUT" != *"no issues found"* ]]; then
    echo "$OUTPUT"
fi

exit 0
