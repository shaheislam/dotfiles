#!/usr/bin/env bash
# Log subagent start/stop events for observability
# Wired to SubagentStart and SubagentStop hook events
set -euo pipefail

EVENT="${CLAUDE_HOOK_EVENT:-unknown}"
LOG="$HOME/.claude/subagent-lifecycle.log"

# Read agent name from stdin JSON if available
AGENT="unknown"
if INPUT=$(cat 2>/dev/null) && [ -n "$INPUT" ]; then
    AGENT=$(echo "$INPUT" | jq -r '.agent_name // .agent.name // "unknown"' 2>/dev/null || echo "unknown")
fi

printf '%s %s agent=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$EVENT" "$AGENT" >>"$LOG"
