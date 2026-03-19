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
echo -e "${BLUE}[1/5] Checking git status...${NC}"
if [[ -n "$(git status --porcelain)" ]]; then
    echo -e "${YELLOW}Warning: Uncommitted changes detected${NC}"
    git status --short
    echo ""
fi

# Step 2: Merge into main (via queue or direct)
echo -e "${BLUE}[2/5] Merging into main...${NC}"

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
echo -e "${BLUE}[3/5] Creating Pull Request...${NC}"

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
echo -e "${BLUE}[4/5] Updating ticket...${NC}"

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
echo -e "${BLUE}[5/5] Sending notification...${NC}"

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
