#!/usr/bin/env bash
# ci-lint-on-save.sh — Claude Code PostToolUse(Edit|Write) hook.
# Runs lightweight lint checks after file modifications in ~/work repos.
# Injects results as systemMessage for Claude context.
#
# Hook protocol:
#   stdin: JSON with tool_name, tool_input, tool_output
#   stdout: JSON with optional {"systemMessage": "..."} for context injection

set -euo pipefail

CI_HOOKS_DIR="$HOME/dotfiles/scripts/ci-hooks"
if [[ ! -d "$CI_HOOKS_DIR" ]]; then
    CI_HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts/ci-hooks" 2>/dev/null && pwd)" || true
fi

# Read hook input
INPUT="$(cat)"

# Extract the file path that was modified
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)" || FILE_PATH=""

[[ -z "$FILE_PATH" ]] && exit 0

# Check if we're in a watched directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
source "$CI_HOOKS_DIR/parse-config.sh" 2>/dev/null || exit 0
ci_config_load 2>/dev/null || exit 0

LINT_ON_SAVE="$(ci_config_setting lint_on_save false)"
[[ "$LINT_ON_SAVE" != "true" ]] && exit 0

# Only run for watched paths
"$CI_HOOKS_DIR/ci-local.sh" --check-only "$PROJECT_DIR" >/dev/null 2>&1 || exit 0

# Determine file type and run appropriate lint
EXT="${FILE_PATH##*.}"
LINT_OUTPUT=""

case "$EXT" in
ts | tsx)
    LINT_OUTPUT="$(cd "$PROJECT_DIR" && npx tsc --noEmit 2>&1 | head -20)" || true
    ;;
py)
    LINT_OUTPUT="$(cd "$PROJECT_DIR" && ruff check "$FILE_PATH" 2>&1 | head -20)" || true
    ;;
go)
    LINT_OUTPUT="$(cd "$PROJECT_DIR" && go vet "$FILE_PATH" 2>&1 | head -20)" || true
    ;;
rs)
    LINT_OUTPUT="$(cd "$PROJECT_DIR" && cargo check --message-format=short 2>&1 | head -20)" || true
    ;;
sh | bash)
    LINT_OUTPUT="$(shellcheck "$FILE_PATH" 2>&1 | head -20)" || true
    ;;
*)
    exit 0
    ;;
esac

if [[ -n "$LINT_OUTPUT" ]]; then
    # Escape for JSON using jq
    LINT_JSON_ESCAPED="$(echo "$LINT_OUTPUT" | jq -Rs .)" || exit 0
    # Remove outer quotes from jq -Rs output
    LINT_CONTENT="${LINT_JSON_ESCAPED:1:-1}"
    echo "{\"systemMessage\":\"[CI lint] ${LINT_CONTENT}\"}"
fi
