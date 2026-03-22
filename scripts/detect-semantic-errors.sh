#!/usr/bin/env bash
#
# detect-semantic-errors.sh - Detect semantic error patterns in agent output
#
# Checks for observable signals that an agent may be confused or looping:
#   1. Repeated identical git commits (looping behavior)
#   2. Excessive tool failures in recent logs
#   3. Ralph-loop iteration at or past max
#   4. Assumption/uncertainty markers in staged changes
#   5. Iteration velocity decline (context bloat signal)
#
# Usage: detect-semantic-errors.sh <worktree-path>
# Exit: 0 = clean, 1 = warnings found (JSON on stdout)

set -euo pipefail

WORKTREE="${1:?Usage: detect-semantic-errors.sh <worktree-path>}"
WARNINGS=()

# Must be a valid directory
[[ -d "$WORKTREE" ]] || exit 0

cd "$WORKTREE"

# 1. Repeated identical commits (last 5 commits with same message = looping)
if git rev-parse --git-dir &>/dev/null 2>&1; then
    commit_msgs=$(git log --oneline -5 --format='%s' 2>/dev/null || true)
    if [[ -n "$commit_msgs" ]]; then
        total_msgs=$(echo "$commit_msgs" | wc -l | tr -d ' ')
        unique_msgs=$(echo "$commit_msgs" | sort -u | wc -l | tr -d ' ')
        if [[ "$total_msgs" -ge 3 && "$unique_msgs" -le 1 ]]; then
            WARNINGS+=("repeated_commits: Last $total_msgs commits have identical messages — agent may be looping")
        fi
    fi
fi

# 2. Excessive tool failures in daily log
FAILURE_LOG="$HOME/.claude/logs/tool-failures-$(date +%Y-%m-%d).jsonl"
if [[ -f "$FAILURE_LOG" ]]; then
    worktree_name=$(basename "$WORKTREE")
    recent_failures=$(tail -100 "$FAILURE_LOG" | grep -c "$worktree_name" 2>/dev/null || echo 0)
    if [[ "$recent_failures" -ge 5 ]]; then
        WARNINGS+=("excessive_failures: $recent_failures tool failures in today's log for $worktree_name")
    fi
fi

# 3. Ralph-loop iteration vs max
RALPH_STATE="$WORKTREE/.claude/ralph-loop.local.md"
if [[ -f "$RALPH_STATE" ]]; then
    iteration=$(grep -o 'Iteration: [0-9]*' "$RALPH_STATE" 2>/dev/null | head -1 | grep -o '[0-9]*' || echo 0)
    max_iter=$(grep -o 'Max iterations: [0-9]*' "$RALPH_STATE" 2>/dev/null | head -1 | grep -o '[0-9]*' || echo 20)
    if [[ "$iteration" -gt 0 && "$iteration" -ge "$max_iter" ]]; then
        WARNINGS+=("max_iterations_reached: Iteration $iteration >= max $max_iter")
    fi
fi

# 4. Assumption markers in staged or recent changes
if git rev-parse --git-dir &>/dev/null 2>&1; then
    # Check both staged and last commit diff
    assumption_count=0
    for diff_src in "git diff --cached" "git diff HEAD~1"; do
        count=$($diff_src 2>/dev/null | grep -ciE '(i.m not sure|i will assume|TODO.*figure|FIXME.*unclear|HACK.*workaround|this might not work|not certain)' || echo 0)
        assumption_count=$((assumption_count + count))
    done
    if [[ "$assumption_count" -ge 3 ]]; then
        WARNINGS+=("assumption_markers: $assumption_count uncertainty markers in recent changes")
    fi
fi

# 5. Iteration velocity check (via progress.json timestamps)
PROGRESS="$WORKTREE/.claude/progress.json"
if [[ -f "$PROGRESS" ]]; then
    iteration=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('iteration',0))" <"$PROGRESS" 2>/dev/null || echo 0)
    updated_at=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('updated_at',''))" <"$PROGRESS" 2>/dev/null || true)

    if [[ -n "$updated_at" && "$iteration" -gt 0 ]]; then
        # Check if progress stalled (no update in 15+ minutes)
        last_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        if [[ "$last_epoch" -gt 0 ]]; then
            stale_seconds=$((now_epoch - last_epoch))
            if [[ "$stale_seconds" -ge 900 ]]; then
                stale_minutes=$((stale_seconds / 60))
                WARNINGS+=("stale_progress: No iteration progress for ${stale_minutes}m — possible context bloat or stuck state")
            fi
        fi
    fi
fi

# Output
if [[ ${#WARNINGS[@]} -eq 0 ]]; then
    exit 0
fi

# JSON output
echo "{"
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
exit 1
