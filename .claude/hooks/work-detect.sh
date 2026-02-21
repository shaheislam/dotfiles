#!/usr/bin/env bash
# work-detect.sh - SessionStart hook to detect active ralph-loop work
#
# If a ralph-loop or ticket-execute session is active in the current project,
# outputs resume context so Claude picks up where it left off.
# Silent exit (no output) when no active work is detected.

set -euo pipefail

# Parse YAML frontmatter value from a state file
parse_yaml() {
    local key="$1" file="$2"
    grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}: *//" | tr -d '"'
}

# Determine project root - prefer CLAUDE_PROJECT_DIR, fall back to git root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

RALPH_FILE="$PROJECT_DIR/.claude/ralph-loop.local.md"
TICKET_FILE="$PROJECT_DIR/.claude/ticket-execute.local.md"

# Check ralph-loop state first, then ticket-execute as fallback
ACTIVE=""
STATE_FILE=""

if [[ -f "$RALPH_FILE" ]] && [[ "$(parse_yaml active "$RALPH_FILE")" == "true" ]]; then
    ACTIVE=1
    STATE_FILE="$RALPH_FILE"
elif [[ -f "$TICKET_FILE" ]] && [[ "$(parse_yaml active "$TICKET_FILE")" == "true" ]]; then
    ACTIVE=1
    STATE_FILE="$TICKET_FILE"
fi

# Silent exit if no active work
[[ -z "$ACTIVE" ]] && exit 0

# Extract state info
ITERATION=$(parse_yaml iteration "$STATE_FILE")
MAX_ITERATIONS=$(parse_yaml max_iterations "$STATE_FILE")
ISSUE_KEY=$(parse_yaml issue_key "$TICKET_FILE" 2>/dev/null)
TITLE=$(parse_yaml title "$TICKET_FILE" 2>/dev/null)

# Build iteration string
ITER_STR=""
if [[ -n "$ITERATION" ]]; then
    ITER_STR="Iteration: ${ITERATION}"
    [[ -n "$MAX_ITERATIONS" ]] && ITER_STR="${ITER_STR}/${MAX_ITERATIONS}"
    ITER_STR="${ITER_STR}."
fi

# Build issue string
ISSUE_STR=""
if [[ -n "$ISSUE_KEY" ]]; then
    ISSUE_STR="${ISSUE_KEY}"
    [[ -n "$TITLE" ]] && ISSUE_STR="${ISSUE_STR} '${TITLE}'"
else
    [[ -n "$TITLE" ]] && ISSUE_STR="'${TITLE}'"
fi

# Seance: check for crash-recovery predecessor context (written by worktree-witness on_crash_retry)
# If present, output it prominently and consume it (ephemeral wisp pattern).
SEANCE_FILE="$PROJECT_DIR/.claude/seance-crash.md"
if [[ -f "$SEANCE_FILE" ]]; then
    cat "$SEANCE_FILE"
    rm -f "$SEANCE_FILE"
    exit 0 # Seance context is complete — skip normal work-detect output
fi

# Try to get latest checkpoint context (fast, local-only)
# PERF: Added 5s timeout to prevent blocking SessionStart on slow git operations
CKPT_SUMMARY=""
if command -v ckpt >/dev/null 2>&1; then
    CKPT_SUMMARY=$(timeout 5 ckpt context --commits 1 2>/dev/null | head -20) || true
fi

# Check for active molecule state
# PERF: Added 5s timeout to prevent blocking SessionStart on slow molecule operations
MOL_SUMMARY=""
MOLECULE_ID=$(parse_yaml "molecule_id" "$TICKET_FILE" 2>/dev/null)
if [[ -n "$MOLECULE_ID" ]]; then
    MOL_SCRIPT="$HOME/dotfiles/scripts/molecule.sh"
    [[ -x "$MOL_SCRIPT" ]] || MOL_SCRIPT="$HOME/dotfiles-gastown/scripts/molecule.sh"
    if [[ -x "$MOL_SCRIPT" ]]; then
        MOL_SUMMARY=$(timeout 5 "$MOL_SCRIPT" resume "$MOLECULE_ID" 2>/dev/null | head -10) || true
    fi
fi

# Build resume message
MSG="RESUME CONTEXT: Working on ${ISSUE_STR:-(unknown task)}."
[[ -n "$ITER_STR" ]] && MSG="$MSG $ITER_STR"
[[ -n "$MOL_SUMMARY" ]] && MSG="$MSG Molecule: $MOL_SUMMARY"
[[ -n "$CKPT_SUMMARY" ]] && MSG="$MSG Checkpoint: $CKPT_SUMMARY"
MSG="$MSG Use /ralph-wiggum:ralph-loop to continue or review the current state."

echo "$MSG"
exit 0
