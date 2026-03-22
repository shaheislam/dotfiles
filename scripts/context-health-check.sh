#!/usr/bin/env bash
#
# context-health-check.sh - Monitor context health during autonomous execution
#
# Checks observable signals of context bloat and degradation:
#   1. Iteration velocity (iterations per hour — declining = possible bloat)
#   2. MCP tool call frequency in failure logs
#   3. Progress staleness
#   4. Worktree file churn (excessive file modifications)
#
# Usage: context-health-check.sh <worktree-path>
# Exit: 0 = healthy, 1 = warnings (JSON on stdout), 2 = critical
#
# Called by worktree-witness.sh on every 10th poll cycle.

set -euo pipefail

WORKTREE="${1:?Usage: context-health-check.sh <worktree-path>}"
WARNINGS=()
CRITICAL=false

[[ -d "$WORKTREE" ]] || exit 0

cd "$WORKTREE"

# 1. Iteration velocity check
PROGRESS="$WORKTREE/.claude/progress.json"
WITNESS_STATE="$WORKTREE/.claude/witness.local.md"

if [[ -f "$PROGRESS" ]]; then
    iteration=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('iteration',0))" <"$PROGRESS" 2>/dev/null || echo 0)
    updated_at=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('updated_at',''))" <"$PROGRESS" 2>/dev/null || true)

    if [[ -n "$updated_at" && "$iteration" -gt 2 ]]; then
        # Compare with witness start time to get velocity
        if [[ -f "$WITNESS_STATE" ]]; then
            started_at=$(grep '^started_at:' "$WITNESS_STATE" 2>/dev/null | head -1 | sed 's/^[^"]*"//; s/"$//' || true)
            if [[ -n "$started_at" ]]; then
                start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null || echo 0)
                now_epoch=$(date +%s)
                if [[ "$start_epoch" -gt 0 ]]; then
                    elapsed_hours=$(echo "scale=2; ($now_epoch - $start_epoch) / 3600" | bc 2>/dev/null || echo 0)
                    if [[ $(echo "$elapsed_hours > 0.1" | bc 2>/dev/null) == "1" ]]; then
                        velocity=$(echo "scale=1; $iteration / $elapsed_hours" | bc 2>/dev/null || echo 0)
                        # If less than 1 iteration per hour after 2+ hours, context may be bloated
                        if [[ $(echo "$elapsed_hours > 2 && $velocity < 1" | bc 2>/dev/null) == "1" ]]; then
                            WARNINGS+=("low_velocity: ${velocity} iterations/hour over ${elapsed_hours}h — context may be bloated")
                        fi
                    fi
                fi
            fi
        fi
    fi
fi

# 2. MCP-related failure frequency
FAILURE_LOG="$HOME/.claude/logs/tool-failures-$(date +%Y-%m-%d).jsonl"
if [[ -f "$FAILURE_LOG" ]]; then
    worktree_name=$(basename "$WORKTREE")
    mcp_failures=$(tail -200 "$FAILURE_LOG" | grep "$worktree_name" | grep -c "mcp__" 2>/dev/null || echo 0)
    if [[ "$mcp_failures" -ge 10 ]]; then
        WARNINGS+=("mcp_failures: $mcp_failures MCP-related failures today — consider --no-mcps")
    fi
fi

# 3. Git diff size check (proxy for context complexity)
if git rev-parse --git-dir &>/dev/null 2>&1; then
    # Check total lines changed since branch creation
    main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    merge_base=$(git merge-base "$main_branch" HEAD 2>/dev/null || true)
    if [[ -n "$merge_base" ]]; then
        diff_stat=$(git diff --stat "$merge_base" HEAD 2>/dev/null | tail -1 || true)
        files_changed=$(echo "$diff_stat" | grep -o '[0-9]* file' | grep -o '[0-9]*' || echo 0)
        if [[ "$files_changed" -ge 50 ]]; then
            WARNINGS+=("large_diff: $files_changed files changed since branch start — scope may have grown")
        fi
    fi
fi

# 4. Check for context compaction signals (multiple compactions = heavy session)
RALPH_STATE="$WORKTREE/.claude/ralph-loop.local.md"
if [[ -f "$RALPH_STATE" ]]; then
    compactions=$(grep -c 'compacted\|Compaction' "$RALPH_STATE" 2>/dev/null || echo 0)
    if [[ "$compactions" -ge 3 ]]; then
        WARNINGS+=("frequent_compaction: $compactions compaction events — session context is heavy")
    fi
fi

# Output
if [[ ${#WARNINGS[@]} -eq 0 ]]; then
    echo '{"status":"healthy","warnings":[],"count":0}'
    exit 0
fi

echo "{"
echo "  \"status\": \"$([ "$CRITICAL" = true ] && echo "critical" || echo "warning")\","
echo "  \"warnings\": ["
for i in "${!WARNINGS[@]}"; do
    comma=""
    [[ $i -lt $((${#WARNINGS[@]} - 1)) ]] && comma=","
    echo "    \"${WARNINGS[$i]}\"$comma"
done
echo "  ],"
echo "  \"count\": ${#WARNINGS[@]},"
echo "  \"worktree\": \"$WORKTREE\","
echo "  \"checked_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
echo "}"
[[ "$CRITICAL" = true ]] && exit 2 || exit 1
