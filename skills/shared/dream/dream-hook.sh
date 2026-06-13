#!/usr/bin/env bash
#
# dream-hook.sh - Stop hook that checks dream conditions and triggers consolidation
#
# Wired in settings.json Stop hook. Fires when a Claude Code session ends.
# Checks if time/session thresholds have been met. If so, spawns claude in the
# background to run the dream consolidation. Zero overhead when conditions
# aren't met (~10ms).

set -euo pipefail

# Guard: never spawn a dream from inside a dream (child session spawned by claude -p)
[ -n "${CLAUDE_PARENT_SESSION_ID:-}" ] && exit 0

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SKILL_DIR/.dream-config"
STATUS_FILE="$SKILL_DIR/.dream-status"

read_config() {
    local key="$1" default="$2"
    if [[ -f "$CONFIG" ]]; then
        grep "^${key}=" "$CONFIG" 2>/dev/null | cut -d= -f2 || echo "$default"
    else
        echo "$default"
    fi
}

LINE_LIMIT=$(read_config "DREAM_LINE_LIMIT" "200")

# Run the condition check
if bash "$SKILL_DIR/should-dream.sh" 2>/dev/null; then
    # Write status: running
    echo "running" >"$STATUS_FILE"

    # Gather session metadata
    SESSION_CONTEXT=""
    if [[ -x "$SKILL_DIR/gather-sessions.sh" ]] || [[ -f "$SKILL_DIR/gather-sessions.sh" ]]; then
        SESSION_CONTEXT=$(bash "$SKILL_DIR/gather-sessions.sh" 2>/dev/null || echo "")
    fi

    # Build the prompt aligned with native autodream
    # Native prompt: "You are performing a dream — a reflective pass over your
    # memory files. Synthesize what you've learned recently into durable,
    # well-organized memories so that future sessions can orient quickly.
    # Update MEMORY.md so it stays under [line limit] lines. It's an index,
    # not a dump — link to memory files with one-line descriptions. Never write
    # memory content directly into it. Return a brief summary of what you
    # consolidated, updated, or pruned. If nothing changed (memories are already
    # tight), say so."
    DREAM_PROMPT="You are performing a dream — a reflective pass over your memory files. Synthesize what you've learned recently into durable, well-organized memories so that future sessions can orient quickly. Update MEMORY.md so it stays under ${LINE_LIMIT} lines. It's an index, not a dump — link to memory files with one-line descriptions. Never write memory content directly into it. Return a brief summary of what you consolidated, updated, or pruned. If nothing changed (memories are already tight), say so.

For detailed guidance on the 4-phase consolidation process, read ~/.claude/skills/dream/SKILL.md.

${SESSION_CONTEXT}"

    # Spawn dream in background
    nohup claude -p "$DREAM_PROMPT" \
        --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
        >"/tmp/dream-$(date +%Y%m%d-%H%M%S).log" 2>&1 &

    DREAM_PID=$!
    echo "Dream consolidation started in background (PID: $DREAM_PID)"

    # Write a completion handler that updates status when done
    (
        wait "$DREAM_PID" 2>/dev/null
        echo "last_ran:$(date +%s)" >"$STATUS_FILE"
        # Reset session counter after successful dream
        echo "0" >"$SKILL_DIR/.session-count"
    ) &
fi

# Always exit 0 so we don't block the session from closing
exit 0
