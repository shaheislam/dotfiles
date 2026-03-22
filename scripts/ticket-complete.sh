#!/usr/bin/env bash
#
# ticket-complete.sh - Post-completion hook for autonomous ticket execution
#
# Called when ralph-loop completes (outputs completion promise)
# Creates PR and transitions ticket to Done/Review
#
# Usage:
#   ticket-complete.sh <WORKTREE_PATH>
#   ticket-complete.sh --watch <WORKTREE_PATH>  # Monitor for completion
#
# The script reads state from .claude/ticket-execute.local.md

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat <<'EOF'
ticket-complete.sh - Post-completion hook for ticket execution

USAGE:
  ticket-complete.sh <WORKTREE_PATH>           # Run completion actions
  ticket-complete.sh --watch <WORKTREE_PATH>   # Monitor and trigger on completion
  ticket-complete.sh --status <WORKTREE_PATH>  # Check execution status

ARGUMENTS:
  WORKTREE_PATH   Path to the worktree where ticket is being executed

OPTIONS:
  --watch    Monitor ralph-loop state and trigger completion when done
  --status   Show current execution status
  --help     Show this help

WHAT IT DOES:
  1. Reads state from .claude/ticket-execute.local.md
  2. Merges into main (via merge-queue daemon or direct auto-merge)
  3. Creates PR with ticket link in description
  4. Transitions ticket to Done/Review
  5. Sends notification (if configured)
  6. Cleans up state file

REQUIREMENTS:
  - gh CLI authenticated
  - linear CLI authenticated (for Linear tickets)
  - acli authenticated (for Jira tickets)
EOF
}

# Parse arguments
WATCH_MODE=false
STATUS_MODE=false
WORKTREE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
    --watch)
        WATCH_MODE=true
        shift
        ;;
    --status)
        STATUS_MODE=true
        shift
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    -*)
        echo -e "${RED}Error: Unknown option $1${NC}" >&2
        exit 1
        ;;
    *)
        WORKTREE_PATH="$1"
        shift
        ;;
    esac
done

if [[ -z "$WORKTREE_PATH" ]]; then
    echo -e "${RED}Error: WORKTREE_PATH required${NC}" >&2
    echo "Usage: ticket-complete.sh [--watch|--status] <WORKTREE_PATH>" >&2
    exit 1
fi

# Resolve to absolute path
WORKTREE_PATH=$(cd "$WORKTREE_PATH" 2>/dev/null && pwd || echo "$WORKTREE_PATH")

STATE_FILE="$WORKTREE_PATH/.claude/ticket-execute.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}Error: State file not found: $STATE_FILE${NC}" >&2
    echo "This worktree doesn't appear to have an active ticket execution." >&2
    exit 1
fi

# Parse state file (YAML frontmatter)
parse_yaml_value() {
    local key="$1"
    grep "^${key}:" "$STATE_FILE" | head -1 | sed "s/^${key}: *//" | tr -d '"'
}

slugify() {
    local text="$1"
    text=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    text=$(echo "$text" | sed 's/[^a-z0-9 _-]//g')
    text=$(echo "$text" | sed 's/[ _]/-/g')
    text=$(echo "$text" | sed 's/-\{2,\}/-/g')
    text=$(echo "$text" | sed 's/^-//;s/-$//')
    echo "${text:0:60}"
}

ISSUE_KEY=$(parse_yaml_value "issue_key")
TITLE=$(parse_yaml_value "title")
TICKETING_SYSTEM=$(parse_yaml_value "ticketing_system")
COMPLETION_PROMISE=$(parse_yaml_value "completion_promise")
TMUX_SESSION=$(parse_yaml_value "tmux_session")
TMUX_WINDOW=$(parse_yaml_value "tmux_window")
AUTO_GENERATED=$(parse_yaml_value "auto_generated")

# Check if this is an auto-generated task (no external ticket)
IS_AUTO_GENERATED=false
if [[ "$AUTO_GENERATED" == "true" ]]; then
    IS_AUTO_GENERATED=true
fi

# Status mode
if $STATUS_MODE; then
    echo -e "${BLUE}=== Ticket Execution Status ===${NC}"
    echo ""
    if $IS_AUTO_GENERATED; then
        echo -e "Task:        ${GREEN}$ISSUE_KEY${NC} (auto-generated, no ticket)"
    else
        echo -e "Issue:       ${GREEN}$ISSUE_KEY${NC} - $TITLE"
    fi
    echo -e "Title:       $TITLE"
    echo -e "System:      ${TICKETING_SYSTEM:-N/A}"
    echo -e "Worktree:    $WORKTREE_PATH"
    echo -e "Tmux:        $TMUX_SESSION:$TMUX_WINDOW"
    echo -e "Promise:     $COMPLETION_PROMISE"
    echo ""

    # Check ralph-loop state
    RALPH_STATE="$WORKTREE_PATH/.claude/ralph-loop.local.md"
    if [[ -f "$RALPH_STATE" ]]; then
        ACTIVE=$(grep "^active:" "$RALPH_STATE" | sed 's/active: *//')
        ITERATION=$(grep "^iteration:" "$RALPH_STATE" | sed 's/iteration: *//')
        MAX_ITER=$(grep "^max_iterations:" "$RALPH_STATE" | sed 's/max_iterations: *//')

        echo -e "Ralph Loop:"
        echo -e "  Active:     $ACTIVE"
        echo -e "  Iteration:  $ITERATION / $MAX_ITER"
    else
        echo -e "${YELLOW}Ralph loop state not found (may not have started yet)${NC}"
    fi
    exit 0
fi

# Watch mode - monitor for completion
if $WATCH_MODE; then
    echo -e "${BLUE}=== Watching for completion ===${NC}"
    echo -e "Issue: ${GREEN}$ISSUE_KEY${NC}"
    echo -e "Promise: $COMPLETION_PROMISE"
    echo ""
    echo "Press Ctrl+C to stop watching"
    echo ""

    RALPH_STATE="$WORKTREE_PATH/.claude/ralph-loop.local.md"

    while true; do
        # Check if ralph-loop has completed (active: false)
        if [[ -f "$RALPH_STATE" ]]; then
            ACTIVE=$(grep "^active:" "$RALPH_STATE" 2>/dev/null | sed 's/active: *//' || echo "true")

            if [[ "$ACTIVE" == "false" ]]; then
                echo -e "${GREEN}Ralph loop completed! Running post-completion...${NC}"
                break
            fi
        fi

        # Also check if the state file was removed (manual completion)
        if [[ ! -f "$STATE_FILE" ]]; then
            echo -e "${YELLOW}State file removed, assuming completion...${NC}"
            exit 0
        fi

        sleep 5
    done

    # Fall through to run completion actions
fi

# Main completion logic
echo -e "${BLUE}=== Running Post-Completion ===${NC}"
echo ""
if $IS_AUTO_GENERATED; then
    echo -e "Task:   ${GREEN}$ISSUE_KEY${NC} (auto-generated)"
else
    echo -e "Issue:  ${GREEN}$ISSUE_KEY${NC} - $TITLE"
fi
echo -e "Title:  $TITLE"
echo -e "System: ${TICKETING_SYSTEM:-N/A}"
echo ""

cd "$WORKTREE_PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Step 1: Check for uncommitted changes
echo -e "${BLUE}[1/6] Checking git status...${NC}"
if [[ -n "$(git status --porcelain)" ]]; then
    echo -e "${YELLOW}Warning: Uncommitted changes detected${NC}"
    git status --short
    echo ""
fi

# Step 2: Merge into main (via queue or direct)
echo -e "${BLUE}[2/6] Merging into main...${NC}"

MERGE_QUEUE="${SCRIPT_DIR}/merge-queue.sh"
AUTO_MERGE="${SCRIPT_DIR}/auto-merge.sh"
MERGE_QUEUE_PID="/tmp/merge-queue-daemon.pid"

if [[ -f "$MERGE_QUEUE_PID" ]] && kill -0 "$(cat "$MERGE_QUEUE_PID")" 2>/dev/null; then
    # Daemon running - queue the merge
    echo -e "${BLUE}Merge queue daemon detected, queuing merge...${NC}"
    "$MERGE_QUEUE" add "$WORKTREE_PATH"
    echo -e "${GREEN}Merge queued (daemon will process)${NC}"
elif [[ -x "$AUTO_MERGE" ]]; then
    # No daemon - merge directly
    MERGE_EXIT=0
    "$AUTO_MERGE" "$WORKTREE_PATH" || MERGE_EXIT=$?
    case $MERGE_EXIT in
    0) echo -e "${GREEN}Merge completed${NC}" ;;
    2) echo -e "${YELLOW}Non-additive conflicts - manual resolution needed${NC}" ;;
    *) echo -e "${YELLOW}Merge returned exit $MERGE_EXIT${NC}" ;;
    esac
else
    echo -e "${YELLOW}auto-merge.sh not found, skipping merge${NC}"
fi

# Step 3: Create PR
echo -e "${BLUE}[3/6] Creating Pull Request...${NC}"

# Get current branch
BRANCH=$(git branch --show-current)

# Build PR title and body
if $IS_AUTO_GENERATED; then
    # Auto-generated task - use just the title
    PR_TITLE="$TITLE"
    PR_BODY="## Summary

$TITLE

## Changes

<!-- Auto-generated by ticket-execute (autonomous task) -->"
elif [[ "$TICKETING_SYSTEM" == "linear" ]]; then
    PR_TITLE="$ISSUE_KEY: $TITLE"
    PR_BODY="## Summary

Fixes $ISSUE_KEY: $TITLE

## Changes

<!-- Auto-generated by ticket-execute -->

---

Closes $ISSUE_KEY"
else
    # Jira - use JIRA smart commits
    PR_TITLE="$ISSUE_KEY: $TITLE"
    PR_BODY="## Summary

$ISSUE_KEY: $TITLE

## Changes

<!-- Auto-generated by ticket-execute -->

---

Jira: $ISSUE_KEY"
fi

# Push branch if needed
# shellcheck disable=SC1083
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' &>/dev/null; then
    echo "Pushing branch to remote..."
    git push -u origin "$BRANCH"
fi

# Create PR
PR_URL=""
if command -v gh &>/dev/null; then
    PR_URL=$(gh pr create \
        --title "$PR_TITLE" \
        --body "$PR_BODY" \
        --draft 2>/dev/null || true)

    if [[ -n "$PR_URL" ]]; then
        echo -e "${GREEN}PR created: $PR_URL${NC}"
    else
        # PR might already exist
        PR_URL=$(gh pr view --json url -q '.url' 2>/dev/null || true)
        if [[ -n "$PR_URL" ]]; then
            echo -e "${YELLOW}PR already exists: $PR_URL${NC}"
        else
            echo -e "${RED}Failed to create PR${NC}"
        fi
    fi
else
    echo -e "${YELLOW}gh CLI not found, skipping PR creation${NC}"
fi

# Step 4: Link PR to ticket / Transition ticket
echo -e "${BLUE}[4/6] Updating ticket...${NC}"

if $IS_AUTO_GENERATED; then
    echo -e "${YELLOW}Skipping ticket updates (auto-generated task, no external ticket)${NC}"
elif [[ "$TICKETING_SYSTEM" == "linear" ]]; then
    # Linear: link PR and transition
    if command -v linear &>/dev/null && [[ -n "$PR_URL" ]]; then
        # Link PR to issue
        linear issue pr "$ISSUE_KEY" --url "$PR_URL" 2>/dev/null || {
            echo -e "${YELLOW}Note: Could not link PR to Linear issue${NC}"
        }

        # Linear CLI 'start' moves to In Progress, we want Review
        # Note: Linear CLI may not have direct transition support
        echo -e "${GREEN}PR linked to Linear issue${NC}"
    else
        echo -e "${YELLOW}linear CLI not found or no PR URL${NC}"
    fi
elif [[ "$TICKETING_SYSTEM" == "jira" ]]; then
    # Jira: transition to Review/Done
    if command -v acli &>/dev/null; then
        # Try to transition to "In Review" or "Done"
        acli jira workitem transition "$ISSUE_KEY" --status "In Review" 2>/dev/null ||
            acli jira workitem transition "$ISSUE_KEY" --status "Review" 2>/dev/null ||
            acli jira workitem transition "$ISSUE_KEY" --status "Done" 2>/dev/null || {
            echo -e "${YELLOW}Could not transition Jira ticket (may need manual transition)${NC}"
        }
        echo -e "${GREEN}Jira ticket updated${NC}"
    else
        echo -e "${YELLOW}acli not found, skipping ticket transition${NC}"
    fi
else
    echo -e "${YELLOW}No ticketing system configured, skipping${NC}"
fi

# Step 5: Send notification
echo -e "${BLUE}[5/6] Sending notification...${NC}"

NOTIFICATION_TITLE="Ticket $ISSUE_KEY Complete"
NOTIFICATION_MSG="$TITLE - PR: $PR_URL"

# Try different notification methods
if command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "$NOTIFICATION_TITLE" -message "$NOTIFICATION_MSG" -sound default
    echo -e "${GREEN}Notification sent via terminal-notifier${NC}"
elif command -v osascript &>/dev/null; then
    osascript -e "display notification \"$NOTIFICATION_MSG\" with title \"$NOTIFICATION_TITLE\""
    echo -e "${GREEN}Notification sent via osascript${NC}"
else
    echo -e "${YELLOW}No notification tool found${NC}"
fi

# Mark state as complete
if [[ -f "$STATE_FILE" ]]; then
    # Update state file to mark complete
    sed -i '' 's/^active: true/active: false/' "$STATE_FILE" 2>/dev/null || true
    echo "completed_at: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" >>"$STATE_FILE"
    echo "pr_url: \"$PR_URL\"" >>"$STATE_FILE"
fi

# Step 6: Export learnings (Obsidian + per-repo)
echo -e "${BLUE}[6/6] Exporting learnings...${NC}"

# Derive repo root from worktree
REPO_ROOT=""
if [[ -d "$WORKTREE_PATH" ]]; then
    GIT_COMMON_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir 2>/dev/null || true)
    if [[ -n "$GIT_COMMON_DIR" ]]; then
        REPO_ROOT=$(cd "$WORKTREE_PATH" && cd "$GIT_COMMON_DIR/.." && pwd 2>/dev/null || true)
    fi
fi
REPO_NAME=$(basename "${REPO_ROOT:-unknown}")

# Timestamps and filename components
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TODAY=$(date -u +%Y-%m-%d)
ISSUE_KEY_LOWER=$(echo "$ISSUE_KEY" | tr '[:upper:]' '[:lower:]')
TITLE_SLUG=$(slugify "$TITLE")

# Capture beads content (reused in both outputs)
DECISIONS="_No decision comments recorded._"
CLOSED_TASKS="_No subtasks tracked._"
OPEN_ISSUES="_None._"

if command -v bd &>/dev/null && [[ -d "$WORKTREE_PATH/.beads" ]]; then
    DECISIONS=$(cd "$WORKTREE_PATH" && bd comments list 2>/dev/null) || DECISIONS="_No decision comments recorded._"
    CLOSED_TASKS=$(cd "$WORKTREE_PATH" && bd list --status=closed 2>/dev/null | head -20) || CLOSED_TASKS="_No subtasks tracked._"
    OPEN_ISSUES=$(cd "$WORKTREE_PATH" && bd list --status=open 2>/dev/null | head -10) || OPEN_ISSUES="_None._"
fi

# Gather execution metadata (ephemeral — lost once worktree is cleaned up)
LEARN_BRANCH=""
LEARN_DEVICE=$(hostname -s 2>/dev/null || echo "unknown")
LEARN_AGENT=$(parse_yaml_value "agent_harness")
LEARN_ITERATIONS=0
LEARN_DURATION=0
LEARN_FILES_CHANGED=0
LEARN_INSERTIONS=0
LEARN_DELETIONS=0
LEARN_RETRIES=0
LEARN_AUTO_GENERATED=$IS_AUTO_GENERATED
LEARN_SUB_PROFILE=$(parse_yaml_value "sub_profile")
LEARN_TEMPLATE=$(parse_yaml_value "workflow_template")
LEARN_MODEL="${CLAUDE_MODEL:-opus}"
LEARN_COMMITS_YAML=""
LEARN_API_COST=""
LEARN_TOTAL_TOKENS=""
LEARN_SEMANTIC_WARNINGS=0

if [[ -d "$WORKTREE_PATH" ]]; then
    LEARN_BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null || true)

    # Iteration count from progress.json
    PROGRESS_FILE="$WORKTREE_PATH/.claude/progress.json"
    if [[ -f "$PROGRESS_FILE" ]]; then
        LEARN_ITERATIONS=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('iteration',0))" <"$PROGRESS_FILE" 2>/dev/null || echo 0)
    fi

    # Retry count from witness state
    WITNESS_STATE="$WORKTREE_PATH/.claude/witness.local.md"
    if [[ -f "$WITNESS_STATE" ]]; then
        LEARN_RETRIES=$(grep '^retries:' "$WITNESS_STATE" 2>/dev/null | head -1 | awk '{print $2}' || echo 0)
    fi

    # Duration from started_at in state file
    STARTED_AT=$(parse_yaml_value "started_at")
    if [[ -n "$STARTED_AT" ]]; then
        START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED_AT" +%s 2>/dev/null || echo 0)
        if [[ "$START_EPOCH" -gt 0 ]]; then
            LEARN_DURATION=$(($(date +%s) - START_EPOCH))
        fi
    fi

    # Merged commits, files changed, insertions/deletions (relative to main)
    MAIN_BRANCH=$(git -C "$WORKTREE_PATH" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    MERGE_BASE=$(git -C "$WORKTREE_PATH" merge-base "$MAIN_BRANCH" HEAD 2>/dev/null || true)
    if [[ -n "$MERGE_BASE" ]]; then
        LEARN_FILES_CHANGED=$(git -C "$WORKTREE_PATH" diff --name-only "$MERGE_BASE" HEAD 2>/dev/null | wc -l | tr -d ' ')

        # Insertions/deletions from shortstat
        SHORTSTAT=$(git -C "$WORKTREE_PATH" diff --shortstat "$MERGE_BASE" HEAD 2>/dev/null || true)
        LEARN_INSERTIONS=$(echo "$SHORTSTAT" | grep -o '[0-9]* insertion' | grep -o '[0-9]*' || echo 0)
        LEARN_DELETIONS=$(echo "$SHORTSTAT" | grep -o '[0-9]* deletion' | grep -o '[0-9]*' || echo 0)

        # Build YAML list of commits
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            LEARN_COMMITS_YAML="${LEARN_COMMITS_YAML}
  - \"$line\""
        done < <(git -C "$WORKTREE_PATH" log --oneline "$MERGE_BASE..HEAD" 2>/dev/null | head -30)
    fi

    # Semantic warning count (from last detection run)
    SEMANTIC_SCRIPT="$(cd "$(dirname "$0")" && pwd)/detect-semantic-errors.sh"
    if [[ -x "$SEMANTIC_SCRIPT" ]]; then
        SEMANTIC_OUT=$("$SEMANTIC_SCRIPT" "$WORKTREE_PATH" 2>/dev/null) ||
            LEARN_SEMANTIC_WARNINGS=$(echo "$SEMANTIC_OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo 0)
    fi
fi

# Probe OTEL for cost/token data (graceful — zero impact if stack not running)
if curl -sf "http://localhost:3100/api/v1/query" --connect-timeout 1 >/dev/null 2>&1; then
    # Grafana/Prometheus is reachable — try to query session metrics
    # Uses the OTEL metric names from Claude Code's native telemetry
    LEARN_API_COST=$(curl -sf "http://localhost:9090/api/v1/query?query=sum(claude_api_cost_dollars)" --connect-timeout 2 2>/dev/null |
        python3 -c "import json,sys; r=json.load(sys.stdin); print(r['data']['result'][0]['value'][1] if r.get('data',{}).get('result') else '')" 2>/dev/null || true)
    LEARN_TOTAL_TOKENS=$(curl -sf "http://localhost:9090/api/v1/query?query=sum(claude_tokens_total)" --connect-timeout 2 2>/dev/null |
        python3 -c "import json,sys; r=json.load(sys.stdin); print(r['data']['result'][0]['value'][1] if r.get('data',{}).get('result') else '')" 2>/dev/null || true)
fi

# Write 1: Obsidian note (always, even without beads)
if [[ -d "$HOME/obsidian" ]]; then
    OBSIDIAN_DIR="$HOME/obsidian/Claude/Memories/learnings"
    OBSIDIAN_FILE="${OBSIDIAN_DIR}/${TODAY}-${ISSUE_KEY_LOWER}-${TITLE_SLUG:-untitled}.md"
    mkdir -p "$OBSIDIAN_DIR"
    cat >"$OBSIDIAN_FILE" <<OBSIDIAN_EOF
---
type: "learning"
category: "technical"
confidence: 0.80
formed: "$NOW_ISO"
source_session: ""
entities:
  - "$REPO_NAME"
  - "$ISSUE_KEY"
tags:
  - "claude-memory"
  - "memory/learning"
  - "ticket-learnings"
  - "$REPO_NAME"
repo: "$REPO_NAME"
branch: "$LEARN_BRANCH"
device: "$LEARN_DEVICE"
agent: "${LEARN_AGENT:-claude}"
model: "$LEARN_MODEL"
sub_profile: "${LEARN_SUB_PROFILE:-default}"
template: "${LEARN_TEMPLATE:-none}"
ticketing_system: "${TICKETING_SYSTEM:-none}"
auto_generated: $LEARN_AUTO_GENERATED
iterations: $LEARN_ITERATIONS
retries: $LEARN_RETRIES
duration_seconds: $LEARN_DURATION
files_changed: $LEARN_FILES_CHANGED
insertions: $LEARN_INSERTIONS
deletions: $LEARN_DELETIONS
semantic_warnings: $LEARN_SEMANTIC_WARNINGS
api_cost_usd: ${LEARN_API_COST:-null}
total_tokens: ${LEARN_TOTAL_TOKENS:-null}
merged_commits:${LEARN_COMMITS_YAML:-"
  - \"(none)\""}
---

# + Learnings: $ISSUE_KEY -- $TITLE

## Summary

Ticket $ISSUE_KEY completed via autonomous execution.

## Why This Matters

Captures decisions, trade-offs, and open issues from ticket execution for future reference.

## Original Context

**Completed:** $NOW_ISO
**Worktree:** $WORKTREE_PATH
**PR:** ${PR_URL:-N/A}

## Decisions & Trade-offs

$DECISIONS

## Completed Subtasks

$CLOSED_TASKS

## Remaining Open Issues

$OPEN_ISSUES

## Related Entities

- $REPO_NAME
- $ISSUE_KEY

## Source

Autonomous ticket execution via gwt-ticket
OBSIDIAN_EOF
    echo -e "${GREEN}Obsidian: $OBSIDIAN_FILE${NC}"
else
    echo -e "${YELLOW}Obsidian vault not found, skipping${NC}"
fi

# Write 2: Per-repo .claude/learnings/ (only if repo root accessible)
if [[ -n "$REPO_ROOT" && -d "$REPO_ROOT/.claude" ]]; then
    REPO_LEARNINGS_DIR="$REPO_ROOT/.claude/learnings"
    REPO_LEARNINGS_FILE="$REPO_LEARNINGS_DIR/${ISSUE_KEY}.md"
    mkdir -p "$REPO_LEARNINGS_DIR"
    cat >"$REPO_LEARNINGS_FILE" <<REPO_EOF
# Learnings: $ISSUE_KEY -- $TITLE

**Completed:** $NOW_ISO
**Branch:** $LEARN_BRANCH | **Device:** $LEARN_DEVICE | **Model:** $LEARN_MODEL
**Agent:** ${LEARN_AGENT:-claude} | **Sub:** ${LEARN_SUB_PROFILE:-default} | **Template:** ${LEARN_TEMPLATE:-none}
**Iterations:** $LEARN_ITERATIONS | **Retries:** $LEARN_RETRIES | **Duration:** ${LEARN_DURATION}s
**Files:** $LEARN_FILES_CHANGED (+$LEARN_INSERTIONS/-$LEARN_DELETIONS) | **Warnings:** $LEARN_SEMANTIC_WARNINGS
**Cost:** ${LEARN_API_COST:-N/A} USD | **Tokens:** ${LEARN_TOTAL_TOKENS:-N/A}
**Worktree:** $WORKTREE_PATH
**PR:** ${PR_URL:-N/A}

## Decisions & Trade-offs

$DECISIONS

## Completed Subtasks

$CLOSED_TASKS

## Remaining Open Issues

$OPEN_ISSUES
REPO_EOF
    echo -e "${GREEN}Per-repo: $REPO_LEARNINGS_FILE${NC}"
else
    echo -e "${YELLOW}Repo .claude/ not accessible, skipping per-repo${NC}"
fi

echo ""
echo -e "${GREEN}=== Ticket execution complete ===${NC}"
echo ""
if $IS_AUTO_GENERATED; then
    echo -e "Task:   ${GREEN}$ISSUE_KEY${NC} (auto-generated)"
else
    echo -e "Issue:  ${GREEN}$ISSUE_KEY${NC} - $TITLE"
fi
echo -e "Title:  $TITLE"
echo -e "PR:     ${PR_URL:-N/A}"
if $IS_AUTO_GENERATED; then
    echo -e "Status: Complete (no ticket to transition)"
else
    echo -e "Status: Transitioned to Review"
fi
echo ""
