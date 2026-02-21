#!/usr/bin/env bash
# nvim-bridge.sh - UserPromptSubmit hook
# Reads Neovim editor state from /tmp/nvim-claude-bridge/<hash>/state.json
# Outputs {"systemMessage": "..."} with current editor context
# Graceful no-op if no state file or Neovim not running

set -euo pipefail

BRIDGE_DIR="/tmp/nvim-claude-bridge"
TTL_SECONDS=300 # 5 minutes

# No bridge dir = no Neovim running, silent exit
[[ -d "$BRIDGE_DIR" ]] || exit 0

# Determine project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

# Find state file for this project
HASH=$(echo -n "$PROJECT_DIR" | shasum -a 256 | cut -c1-8)
STATE_FILE="$BRIDGE_DIR/$HASH/state.json"

[[ -f "$STATE_FILE" ]] || exit 0

# Check Neovim PID is still alive
NVIM_PID=$(jq -r '.nvim_pid // empty' "$STATE_FILE" 2>/dev/null)
if [[ -n "$NVIM_PID" ]] && ! kill -0 "$NVIM_PID" 2>/dev/null; then
    # Neovim exited, clean up stale state
    rm -rf "$BRIDGE_DIR/$HASH" 2>/dev/null
    exit 0
fi

NOW=$(date +%s)
PARTS=()

# Diagnostics section
DIAG_TS=$(jq -r '.diagnostics.timestamp // 0' "$STATE_FILE" 2>/dev/null)
if [[ $((NOW - DIAG_TS)) -lt $TTL_SECONDS ]]; then
    ERRORS=$(jq -r '.diagnostics.error_count // 0' "$STATE_FILE" 2>/dev/null)
    WARNINGS=$(jq -r '.diagnostics.warning_count // 0' "$STATE_FILE" 2>/dev/null)
    if [[ "$ERRORS" -gt 0 || "$WARNINGS" -gt 0 ]]; then
        DIAG_LINES=$(jq -r '
            [(.diagnostics.errors // [] | .[] | "\(.file):\(.line) \(.source): \(.message)"),
             (.diagnostics.warnings // [] | .[] | "\(.file):\(.line) \(.source): \(.message)")]
            | join("; ")' "$STATE_FILE" 2>/dev/null)
        PARTS+=("Diagnostics(${ERRORS}E/${WARNINGS}W): ${DIAG_LINES}")
    fi
fi

# Focus section
FOCUS_TS=$(jq -r '.focus.timestamp // 0' "$STATE_FILE" 2>/dev/null)
if [[ $((NOW - FOCUS_TS)) -lt $TTL_SECONDS ]]; then
    FOCUS_FILE=$(jq -r '.focus.file // empty' "$STATE_FILE" 2>/dev/null)
    FOCUS_LINE=$(jq -r '.focus.line // empty' "$STATE_FILE" 2>/dev/null)
    FOCUS_FT=$(jq -r '.focus.filetype // empty' "$STATE_FILE" 2>/dev/null)
    if [[ -n "$FOCUS_FILE" ]]; then
        PARTS+=("Focus: ${FOCUS_FILE}:${FOCUS_LINE} (${FOCUS_FT})")
    fi
fi

# Git hunks section
GIT_TS=$(jq -r '.git_hunks.timestamp // 0' "$STATE_FILE" 2>/dev/null)
if [[ $((NOW - GIT_TS)) -lt $TTL_SECONDS ]]; then
    GIT_SUMMARY=$(jq -r '.git_hunks.summary // empty' "$STATE_FILE" 2>/dev/null)
    if [[ -n "$GIT_SUMMARY" ]]; then
        GIT_FILES=$(jq -r '.git_hunks.files_changed // [] | join(", ")' "$STATE_FILE" 2>/dev/null)
        PARTS+=("Git: ${GIT_SUMMARY} [${GIT_FILES}]")
    fi
fi

# Tests section
TEST_TS=$(jq -r '.tests.timestamp // 0' "$STATE_FILE" 2>/dev/null)
if [[ $((NOW - TEST_TS)) -lt $TTL_SECONDS ]]; then
    TEST_STATUS=$(jq -r '.tests.status // empty' "$STATE_FILE" 2>/dev/null)
    if [[ -n "$TEST_STATUS" ]]; then
        PASSED=$(jq -r '.tests.passed_count // 0' "$STATE_FILE" 2>/dev/null)
        FAILED=$(jq -r '.tests.failed_count // 0' "$STATE_FILE" 2>/dev/null)
        TEST_MSG="${TEST_STATUS} (${PASSED} passed, ${FAILED} failed)"
        if [[ "$TEST_STATUS" == "fail" ]]; then
            FAIL_DETAILS=$(jq -r '.tests.failed // [] | .[] | "\(.name): \(.message)"' "$STATE_FILE" 2>/dev/null | head -5)
            [[ -n "$FAIL_DETAILS" ]] && TEST_MSG="${TEST_MSG} — ${FAIL_DETAILS}"
        fi
        PARTS+=("Tests: ${TEST_MSG}")
    fi
fi

# Silent exit if no fresh sections
[[ ${#PARTS[@]} -eq 0 ]] && exit 0

# Build system message
MSG="Neovim context: $(
    IFS='|'
    echo "${PARTS[*]}" | sed 's/|/ | /g'
)"

# Output for Claude Code hook
echo "{\"systemMessage\": $(echo "$MSG" | jq -Rs .)}"
