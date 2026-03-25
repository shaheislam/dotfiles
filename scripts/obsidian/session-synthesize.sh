#!/usr/bin/env bash
#
# session-synthesize.sh - Synthesize Claude Code session into Obsidian documentation
#
# Gathers session context (plan.md, CHANGELOG.md, git diff, beads data)
# and uses claude --print to generate structured Obsidian documentation.
#
# Usage:
#   session-synthesize.sh [OPTIONS]
#   session-synthesize.sh --worktree /path/to/worktree
#   session-synthesize.sh --cwd /path/to/project
#   session-synthesize.sh --dry-run
#
# Output:
#   Writes to ~/obsidian/Claude/Sessions/<date>-<slug>.md
#   Optionally scatters to project-specific vault folders

set -euo pipefail

# Configuration
OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/obsidian}"
CLAUDE_SESSIONS_DIR="$OBSIDIAN_VAULT/Claude/Sessions"
TODAY=$(date -u +%Y-%m-%d)
TIMESTAMP=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DRY_RUN=false
WORKTREE_PATH=""
PROJECT_CWD=""
TICKET_ID=""
VERBOSE=false

show_help() {
    cat <<'EOF'
session-synthesize.sh - Synthesize Claude session into Obsidian

USAGE:
  session-synthesize.sh [OPTIONS]

OPTIONS:
  --worktree PATH   Worktree path (for gwt-ticket sessions)
  --cwd PATH        Project working directory (default: current dir)
  --ticket ID       Ticket/issue ID to associate
  --dry-run         Print synthesis prompt without writing
  --verbose         Show gathered context
  --help            Show this help

ENVIRONMENT:
  OBSIDIAN_VAULT    Path to Obsidian vault (default: ~/obsidian)

WHAT IT DOES:
  1. Gathers session context from available sources
  2. Builds a synthesis prompt with all context
  3. Calls claude --print to generate documentation
  4. Writes to ~/obsidian/Claude/Sessions/
  5. Optionally scatters to project-specific vault sections
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --worktree)
        WORKTREE_PATH="$2"
        shift 2
        ;;
    --cwd)
        PROJECT_CWD="$2"
        shift 2
        ;;
    --ticket)
        TICKET_ID="$2"
        shift 2
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --verbose)
        VERBOSE=true
        shift
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    *)
        echo -e "${RED}Error: Unknown option $1${NC}" >&2
        exit 1
        ;;
    esac
done

# Resolve working directory
if [[ -n "$WORKTREE_PATH" ]]; then
    PROJECT_CWD="$WORKTREE_PATH"
elif [[ -z "$PROJECT_CWD" ]]; then
    PROJECT_CWD="${PWD}"
fi

# Ensure Obsidian vault exists
if [[ ! -d "$OBSIDIAN_VAULT" ]]; then
    echo -e "${RED}Error: Obsidian vault not found at $OBSIDIAN_VAULT${NC}" >&2
    exit 1
fi

mkdir -p "$CLAUDE_SESSIONS_DIR"

# --- Context Gathering ---

gather_plan() {
    local plan_file="$PROJECT_CWD/.claude/plan.md"
    if [[ -f "$plan_file" ]]; then
        cat "$plan_file"
    fi
}

gather_changelog() {
    local changelog="$PROJECT_CWD/.claude/CHANGELOG.md"
    if [[ -f "$changelog" ]]; then
        tail -100 "$changelog"
    fi
}

gather_git_context() {
    if ! git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
        return
    fi

    echo "### Branch"
    git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || echo "(detached)"

    echo ""
    echo "### Recent Commits"
    # Get commits since worktree creation or last 20
    local main_branch
    main_branch=$(git -C "$PROJECT_CWD" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    local merge_base
    merge_base=$(git -C "$PROJECT_CWD" merge-base "$main_branch" HEAD 2>/dev/null || true)

    if [[ -n "$merge_base" ]]; then
        git -C "$PROJECT_CWD" log --oneline "$merge_base..HEAD" 2>/dev/null | head -30
    else
        git -C "$PROJECT_CWD" log --oneline -20 2>/dev/null
    fi

    echo ""
    echo "### Files Changed"
    if [[ -n "$merge_base" ]]; then
        git -C "$PROJECT_CWD" diff --stat "$merge_base" HEAD 2>/dev/null | tail -20
    else
        git -C "$PROJECT_CWD" diff --stat HEAD~5 HEAD 2>/dev/null | tail -20
    fi
}

gather_beads() {
    if ! command -v bd &>/dev/null; then
        return
    fi
    if [[ ! -d "$PROJECT_CWD/.beads" ]]; then
        return
    fi

    echo "### Open Issues"
    (cd "$PROJECT_CWD" && bd list --status=open 2>/dev/null | head -15) || true

    echo ""
    echo "### Closed Issues"
    (cd "$PROJECT_CWD" && bd list --status=closed 2>/dev/null | head -15) || true

    echo ""
    echo "### Decisions & Comments"
    (cd "$PROJECT_CWD" && bd comments list 2>/dev/null | head -20) || true
}

gather_ticket_state() {
    local state_file="$PROJECT_CWD/.claude/ticket-execute.local.md"
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    fi
}

# Derive a title slug from available context
derive_title() {
    # Try ticket state first
    local state_file="$PROJECT_CWD/.claude/ticket-execute.local.md"
    if [[ -f "$state_file" ]]; then
        local title
        title=$(grep '^title:' "$state_file" | head -1 | sed 's/^title: *//' | tr -d '"')
        if [[ -n "$title" ]]; then
            echo "$title"
            return
        fi
    fi

    # Try plan.md title
    local plan_file="$PROJECT_CWD/.claude/plan.md"
    if [[ -f "$plan_file" ]]; then
        local plan_title
        plan_title=$(grep '^title:' "$plan_file" | head -1 | sed 's/^title: *//' | tr -d '"')
        if [[ -n "$plan_title" ]]; then
            echo "$plan_title"
            return
        fi
    fi

    # Fall back to branch name
    if git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
        local branch
        branch=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || true)
        if [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]]; then
            echo "$branch"
            return
        fi
    fi

    # Last resort: directory name
    basename "$PROJECT_CWD"
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

# --- Gather All Context ---

PLAN_CONTEXT=$(gather_plan)
CHANGELOG_CONTEXT=$(gather_changelog)
GIT_CONTEXT=$(gather_git_context)
BEADS_CONTEXT=$(gather_beads)
TICKET_STATE=$(gather_ticket_state)
SESSION_TITLE=$(derive_title)
TITLE_SLUG=$(slugify "$SESSION_TITLE")

# Derive project name
PROJECT_NAME=$(basename "$PROJECT_CWD")
REPO_NAME=""
if git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
    local_common=$(git -C "$PROJECT_CWD" rev-parse --git-common-dir 2>/dev/null || true)
    if [[ -n "$local_common" ]]; then
        REPO_NAME=$(cd "$PROJECT_CWD" && cd "$local_common/.." && basename "$(pwd)" 2>/dev/null || echo "$PROJECT_NAME")
    fi
fi
REPO_NAME="${REPO_NAME:-$PROJECT_NAME}"

if $VERBOSE; then
    echo -e "${BLUE}=== Gathered Context ===${NC}"
    echo -e "Title: $SESSION_TITLE"
    echo -e "Project: $PROJECT_NAME"
    echo -e "Repo: $REPO_NAME"
    echo -e "Plan: $(echo "$PLAN_CONTEXT" | wc -l | tr -d ' ') lines"
    echo -e "Changelog: $(echo "$CHANGELOG_CONTEXT" | wc -l | tr -d ' ') lines"
    echo -e "Git: $(echo "$GIT_CONTEXT" | wc -l | tr -d ' ') lines"
    echo -e "Beads: $(echo "$BEADS_CONTEXT" | wc -l | tr -d ' ') lines"
    echo ""
fi

# --- Build Synthesis Prompt ---

SYNTHESIS_PROMPT="# Session Synthesis Task

You are synthesizing a Claude Code session into structured Obsidian documentation.
Generate a comprehensive session document in markdown format.

## Session Info
- **Date:** $TODAY
- **Project:** $REPO_NAME
- **Title:** $SESSION_TITLE
- **Ticket:** ${TICKET_ID:-N/A}

## Available Context

### Plan (Living Document)
\`\`\`
${PLAN_CONTEXT:-No plan.md found}
\`\`\`

### Session Changelog
\`\`\`
${CHANGELOG_CONTEXT:-No changelog found}
\`\`\`

### Git Activity
\`\`\`
${GIT_CONTEXT:-No git context available}
\`\`\`

### Beads (Issue Tracking)
\`\`\`
${BEADS_CONTEXT:-No beads data available}
\`\`\`

### Ticket Execution State
\`\`\`
${TICKET_STATE:-No ticket state found}
\`\`\`

## Output Requirements

Generate ONLY the markdown content (no code fences wrapping the output). Structure:

1. **YAML Frontmatter** with:
   - type: claude-session-synthesis
   - date: $TODAY
   - project: $REPO_NAME
   - title: (descriptive title)
   - tags: [claude-session, project/$REPO_NAME, ...]
   - ticket: ${TICKET_ID:-null}
   - status: completed

2. **# Title** - descriptive session title

3. **## Objective** - what the session set out to accomplish

4. **## Approach** - how the work was structured

5. **## What Was Done** - concrete changes, decisions, implementations
   - Include specific file paths and code changes where relevant
   - Reference commit messages

6. **## Key Decisions** - important choices and their rationale

7. **## Outcomes** - what was achieved, what remains

8. **## Lessons & Insights** - anything worth remembering for future sessions

## Rules
- Be specific and concrete, not vague
- Reference actual files, commits, and tool names
- Keep it useful for future reference
- If context is sparse, create a shorter document rather than padding
- Do NOT wrap the entire output in a code block"

# --- Execute Synthesis ---

if $DRY_RUN; then
    echo -e "${BLUE}=== Synthesis Prompt (dry run) ===${NC}"
    echo "$SYNTHESIS_PROMPT"
    exit 0
fi

# Check if there's enough context to synthesize
TOTAL_CONTEXT_LEN=$((${#PLAN_CONTEXT} + ${#CHANGELOG_CONTEXT} + ${#GIT_CONTEXT} + ${#BEADS_CONTEXT}))
if [[ $TOTAL_CONTEXT_LEN -lt 50 ]]; then
    echo -e "${YELLOW}Insufficient session context to synthesize (${TOTAL_CONTEXT_LEN} chars). Skipping.${NC}" >&2
    exit 0
fi

echo -e "${BLUE}Synthesizing session to Obsidian...${NC}"

# Call claude for synthesis
SYNTHESIS_OUTPUT=""
if command -v claude &>/dev/null; then
    SYNTHESIS_OUTPUT=$(claude --print -p "$SYNTHESIS_PROMPT" 2>/dev/null) || {
        echo -e "${YELLOW}Claude synthesis call failed, falling back to template${NC}" >&2
        SYNTHESIS_OUTPUT=""
    }
fi

# Fallback: if claude unavailable or failed, generate a template
if [[ -z "$SYNTHESIS_OUTPUT" ]]; then
    SYNTHESIS_OUTPUT="---
type: claude-session-synthesis
date: \"$TODAY\"
project: \"$REPO_NAME\"
title: \"$SESSION_TITLE\"
tags:
  - \"claude-session\"
  - \"project/$REPO_NAME\"
ticket: \"${TICKET_ID:-null}\"
status: completed
---

# Session: $SESSION_TITLE

## Objective

$(echo "$PLAN_CONTEXT" | sed -n '/^## Objective/,/^## /p' | head -10 | tail -n +2)

## What Was Done

### Git Activity
$GIT_CONTEXT

### Beads
$BEADS_CONTEXT

## Changelog
$CHANGELOG_CONTEXT
"
fi

# --- Write to Obsidian ---

OUTPUT_FILE="$CLAUDE_SESSIONS_DIR/${TODAY}-synth-${TITLE_SLUG:-session}.md"

# Avoid overwriting - add timestamp suffix if file exists
if [[ -f "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="$CLAUDE_SESSIONS_DIR/${TODAY}-synth-${TITLE_SLUG:-session}-${TIMESTAMP}.md"
fi

echo "$SYNTHESIS_OUTPUT" >"$OUTPUT_FILE"
echo -e "${GREEN}Session synthesized: $OUTPUT_FILE${NC}"

# --- Scatter to project folder (if exists in vault) ---

PROJECT_VAULT_DIR="$OBSIDIAN_VAULT/$REPO_NAME"
if [[ -d "$PROJECT_VAULT_DIR" ]]; then
    PROJECT_SESSIONS_DIR="$PROJECT_VAULT_DIR/Sessions"
    mkdir -p "$PROJECT_SESSIONS_DIR"
    cp "$OUTPUT_FILE" "$PROJECT_SESSIONS_DIR/"
    echo -e "${GREEN}Scattered to project: $PROJECT_SESSIONS_DIR/$(basename "$OUTPUT_FILE")${NC}"
fi

# Also scatter to Projects/ if it exists
PROJECTS_DIR="$OBSIDIAN_VAULT/Projects"
if [[ -d "$PROJECTS_DIR" ]]; then
    # Check if there's a matching project folder
    for proj_dir in "$PROJECTS_DIR"/*/; do
        proj_name=$(basename "$proj_dir")
        if [[ "${proj_name,,}" == "${REPO_NAME,,}" ]]; then
            mkdir -p "$proj_dir/Sessions"
            cp "$OUTPUT_FILE" "$proj_dir/Sessions/"
            echo -e "${GREEN}Scattered to project: $proj_dir/Sessions/$(basename "$OUTPUT_FILE")${NC}"
            break
        fi
    done
fi

echo -e "${GREEN}Session synthesis complete${NC}"
