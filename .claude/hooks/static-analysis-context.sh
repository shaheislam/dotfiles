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
#   - Snippet redaction: strips code_snippet from prompt output (configurable)
#   - Severity gate: only surfaces warning+ by default (configurable)
#   - Stale TTL: cached findings expire after FINDINGS_TTL_SECS (default 60s)
#   - Suppression: respects inline # noqa, # shellcheck disable, # aigateway:ignore
#   - Audit log: optionally logs what enters agent context

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
GATEWAY_SCRIPT="$PROJECT_DIR/scripts/aigateway/analyze.sh"

# Configuration (override via environment)
DEBOUNCE_SECS="${AIGATEWAY_DEBOUNCE_SECS:-3}"
MIN_SEVERITY="${AIGATEWAY_MIN_SEVERITY:-warning}"
FINDINGS_TTL_SECS="${AIGATEWAY_FINDINGS_TTL:-60}"
REDACT_SNIPPETS="${AIGATEWAY_REDACT_SNIPPETS:-false}"
AUDIT_LOG="${AIGATEWAY_AUDIT_LOG:-}" # Set to a path to enable
STATE_DIR="/tmp/aigateway-hooks"
mkdir -p "$STATE_DIR"

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

# Compute a stable key for this file (used for marker/lock/cache)
FILE_KEY=$(echo "$FILE_PATH" | sed 's|/|_|g')

# ─── Debounce: skip if same file analyzed recently ────────
MARKER_FILE="$STATE_DIR/${FILE_KEY}.marker"
if [[ -f "$MARKER_FILE" ]]; then
    MARKER_AGE=$(($(date +%s) - $(stat -f '%m' "$MARKER_FILE" 2>/dev/null || stat -c '%Y' "$MARKER_FILE" 2>/dev/null || echo 0)))
    if [[ "$MARKER_AGE" -lt "$DEBOUNCE_SECS" ]]; then
        exit 0
    fi
fi

# ─── Lockfile: prevent concurrent analysis of same file ───
LOCK_DIR_FILE="$STATE_DIR/${FILE_KEY}.lock.d"
if ! mkdir "$LOCK_DIR_FILE" 2>/dev/null; then
    if [[ -d "$LOCK_DIR_FILE" ]]; then
        LOCK_AGE=$(($(date +%s) - $(stat -f '%m' "$LOCK_DIR_FILE" 2>/dev/null || stat -c '%Y' "$LOCK_DIR_FILE" 2>/dev/null || echo 0)))
        if [[ "$LOCK_AGE" -gt 30 ]]; then
            rmdir "$LOCK_DIR_FILE" 2>/dev/null || true
            mkdir "$LOCK_DIR_FILE" 2>/dev/null || exit 0
        else
            exit 0
        fi
    fi
fi
trap 'rmdir "$LOCK_DIR_FILE" 2>/dev/null || true' EXIT

# Update debounce marker
touch "$MARKER_FILE"

# ─── Stale findings TTL: invalidate old cached results ────
# If the file was modified more recently than the last analysis,
# or if the last analysis is older than TTL, force re-analysis.
CACHE_FILE="$STATE_DIR/${FILE_KEY}.cache"
if [[ -f "$CACHE_FILE" ]]; then
    CACHE_AGE=$(($(date +%s) - $(stat -f '%m' "$CACHE_FILE" 2>/dev/null || stat -c '%Y' "$CACHE_FILE" 2>/dev/null || echo 0)))
    FILE_MTIME=$(stat -f '%m' "$FILE_PATH" 2>/dev/null || stat -c '%Y' "$FILE_PATH" 2>/dev/null || echo 0)
    CACHE_MTIME=$(stat -f '%m' "$CACHE_FILE" 2>/dev/null || stat -c '%Y' "$CACHE_FILE" 2>/dev/null || echo 0)

    if [[ "$CACHE_AGE" -lt "$FINDINGS_TTL_SECS" && "$CACHE_MTIME" -gt "$FILE_MTIME" ]]; then
        # Cache is fresh and file hasn't changed — use cached results
        OUTPUT=$(cat "$CACHE_FILE")
        if [[ -n "$OUTPUT" ]]; then
            echo "$OUTPUT"
        fi
        exit 0
    fi
    # Cache stale or file changed — re-analyze below
fi

# Only analyze files we have tools for
case "$FILE_PATH" in
*.sh | *.bash | *.py | *.pyi | *.ts | *.tsx | *.js | *.jsx | *.go) ;;
*)
    if ! head -1 "$FILE_PATH" 2>/dev/null | grep -qE '^#!.*\b(bash|sh|python)\b'; then
        exit 0
    fi
    ;;
esac

# Select the fastest tool for the file type
TOOL_ARG=""
case "$FILE_PATH" in
*.sh | *.bash) TOOL_ARG="--tool shellcheck" ;;
*.py | *.pyi) TOOL_ARG="--tool ruff" ;;
*) exit 0 ;;
esac

RAW_OUTPUT=$("$GATEWAY_SCRIPT" $TOOL_ARG --severity "$MIN_SEVERITY" --agent-context "$FILE_PATH" 2>/dev/null || true)

# ─── Suppression: filter out findings for suppressed lines ──
# Respects: # noqa, # shellcheck disable=SCxxxx, # aigateway:ignore
if [[ -n "$RAW_OUTPUT" && "$RAW_OUTPUT" != *"no issues found"* ]]; then
    # Build list of suppressed line numbers from the source file
    SUPPRESSED_LINES=""
    if [[ -f "$FILE_PATH" ]]; then
        SUPPRESSED_LINES=$(grep -n '# *noqa\|# *shellcheck disable\|# *aigateway:ignore' "$FILE_PATH" 2>/dev/null | cut -d: -f1 | tr '\n' '|' | sed 's/|$//' || true)
    fi

    if [[ -n "$SUPPRESSED_LINES" ]]; then
        # Remove lines matching suppressed line numbers from prompt output
        RAW_OUTPUT=$(echo "$RAW_OUTPUT" | grep -vE "line ($SUPPRESSED_LINES):" || true)
    fi
fi

# ─── Redact absolute paths to project-relative ────────────
OUTPUT="$RAW_OUTPUT"
if [[ -n "$PROJECT_DIR" && "$PROJECT_DIR" != "." ]]; then
    OUTPUT=$(echo "$OUTPUT" | sed "s|$PROJECT_DIR/||g")
fi

# ─── Snippet redaction (opt-in) ──────────────────────────
if [[ "$REDACT_SNIPPETS" == "true" ]]; then
    OUTPUT=$(echo "$OUTPUT" | sed '/^    [0-9]*|/d')
fi

# Only emit if there are actual findings remaining after filtering
if [[ -z "$OUTPUT" || "$OUTPUT" == *"no issues found"* || ! "$OUTPUT" =~ [a-zA-Z] ]]; then
    # Cache empty result to avoid re-running until TTL
    echo -n "" >"$CACHE_FILE"
    exit 0
fi

# Cache the findings for TTL reuse
echo "$OUTPUT" >"$CACHE_FILE"

# ─── Audit log (opt-in) ─────────────────────────────────
if [[ -n "$AUDIT_LOG" ]]; then
    {
        echo "---"
        echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "file: $FILE_PATH"
        echo "tool: ${TOOL_ARG#--tool }"
        echo "findings_injected: true"
        echo "line_count: $(echo "$OUTPUT" | wc -l | tr -d ' ')"
    } >>"$AUDIT_LOG"
fi

echo "$OUTPUT"
exit 0
