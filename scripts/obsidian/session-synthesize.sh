#!/usr/bin/env bash
#
# session-synthesize.sh - Synthesize Claude Code session into Obsidian documentation
#
# Gathers session context (plan.md, CHANGELOG.md, git diff, beads data)
# and uses claude --print to generate structured Obsidian documentation.
#
# Idempotent: uses a stable session ID derived from (branch + project + date).
# If the output file already exists, the script exits early (no duplicates).
#
# Usage:
#   session-synthesize.sh [OPTIONS]
#   session-synthesize.sh --worktree /path/to/worktree
#   session-synthesize.sh --cwd /path/to/project
#   session-synthesize.sh --dry-run
#
# Output:
#   Writes to ~/obsidian/Claude/Sessions/<date>-synth-<session-id>.md
#   Adds Obsidian link in project folder (no file copies)

set -euo pipefail

# Configuration
OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/obsidian}"
CLAUDE_SESSIONS_DIR="$OBSIDIAN_VAULT/Claude/Sessions"
TODAY=$(date -u +%Y-%m-%d)
MAX_PROMPT_BYTES=30000 # Cap prompt size to avoid oversized API calls

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
  1. Derives a stable session ID from (branch + project + date)
  2. If output file already exists, exits (idempotent)
  3. Gathers session context from available sources
  4. Redacts secrets/sensitive patterns from context
  5. Calls claude --print to generate documentation
  6. Validates output has required frontmatter fields
  7. Writes canonical note to ~/obsidian/Claude/Sessions/
  8. Adds Obsidian wikilink in project folder (no file copies)
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

# --- Utilities ---

slugify() {
    local text="$1"
    text=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    text=$(echo "$text" | sed 's/[^a-z0-9 _-]//g')
    text=$(echo "$text" | sed 's/[ _]/-/g')
    text=$(echo "$text" | sed 's/-\{2,\}/-/g')
    text=$(echo "$text" | sed 's/^-//;s/-$//')
    echo "${text:0:60}"
}

# Redact secrets and sensitive content from text.
# Strips: API keys, tokens, passwords, AWS creds, private keys.
redact_secrets() {
    sed \
        -e 's/sk-[a-zA-Z0-9_-]\{10,\}/[REDACTED_API_KEY]/g' \
        -e 's/ghp_[a-zA-Z0-9]\{36,\}/[REDACTED_GH_TOKEN]/g' \
        -e 's/AKIA[A-Z0-9]\{16\}/[REDACTED_AWS_KEY]/g' \
        -e 's/Bearer [a-zA-Z0-9._-]\{20,\}/[REDACTED_BEARER]/g' \
        -e 's/-----BEGIN.*PRIVATE KEY-----/[REDACTED_PRIVATE_KEY]/g' \
        -e 's/-----END.*PRIVATE KEY-----//g'
}

# Truncate text to a max byte count, appending a marker if truncated.
truncate_to() {
    local max_bytes="$1"
    local input
    input=$(cat)
    if [[ ${#input} -gt $max_bytes ]]; then
        echo "${input:0:$max_bytes}"
        echo ""
        echo "[... truncated at ${max_bytes} bytes ...]"
    else
        echo "$input"
    fi
}

# --- Derive Stable Session ID ---
# Combines branch + project + date into a deterministic ID.
# Multiple callers (Stop hook, ticket-complete.sh, manual oss) hitting the same
# session on the same day will compute the same ID and hit the dedup check.

derive_session_id() {
    local branch=""
    if git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
        branch=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || echo "detached")
    fi
    local project
    project=$(basename "$PROJECT_CWD")
    # md5 of (branch + project + date) gives a stable 8-char ID
    echo -n "${branch}:${project}:${TODAY}" | md5sum | cut -c1-8
}

SESSION_ID=$(derive_session_id)
OUTPUT_FILE="$CLAUDE_SESSIONS_DIR/${TODAY}-synth-${SESSION_ID}.md"

# --- Idempotency Check (Concern #1: dedup across Stop + ticket-complete + manual) ---
if [[ -f "$OUTPUT_FILE" ]] && ! $DRY_RUN; then
    echo -e "${YELLOW}Session already synthesized: $OUTPUT_FILE${NC}"
    exit 0
fi

# --- Context Gathering ---

gather_plan() {
    local plan_file="$PROJECT_CWD/.claude/plan.md"
    if [[ -f "$plan_file" ]]; then
        cat "$plan_file" | redact_secrets
    fi
}

gather_changelog() {
    local changelog="$PROJECT_CWD/.claude/CHANGELOG.md"
    if [[ -f "$changelog" ]]; then
        tail -100 "$changelog" | redact_secrets
    fi
}

gather_git_context() {
    if ! git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
        return
    fi

    local branch
    branch=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || echo "(detached)")
    echo "### Branch"
    echo "$branch"

    echo ""
    echo "### Recent Commits (this branch only)"
    # Scope to current branch only (Concern #3: avoid unrelated changes)
    local main_branch
    main_branch=$(git -C "$PROJECT_CWD" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    local merge_base
    merge_base=$(git -C "$PROJECT_CWD" merge-base "$main_branch" HEAD 2>/dev/null || true)

    if [[ -n "$merge_base" ]]; then
        git -C "$PROJECT_CWD" log --oneline "$merge_base..HEAD" 2>/dev/null | head -30
    else
        git -C "$PROJECT_CWD" log --oneline -10 2>/dev/null
    fi

    echo ""
    echo "### Files Changed (stat only, no diffs)"
    # Use --stat only (no raw diffs) to avoid leaking secrets (Concern #3)
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
        cat "$state_file" | redact_secrets
    fi
}

# Derive a human-readable title from available context
derive_title() {
    local state_file="$PROJECT_CWD/.claude/ticket-execute.local.md"
    if [[ -f "$state_file" ]]; then
        local title
        title=$(grep '^title:' "$state_file" | head -1 | sed 's/^title: *//' | tr -d '"')
        if [[ -n "$title" ]]; then
            echo "$title"
            return
        fi
    fi

    local plan_file="$PROJECT_CWD/.claude/plan.md"
    if [[ -f "$plan_file" ]]; then
        local plan_title
        plan_title=$(grep '^title:' "$plan_file" | head -1 | sed 's/^title: *//' | tr -d '"')
        if [[ -n "$plan_title" ]]; then
            echo "$plan_title"
            return
        fi
    fi

    if git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
        local branch
        branch=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || true)
        if [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]]; then
            echo "$branch"
            return
        fi
    fi

    basename "$PROJECT_CWD"
}

# --- Gather All Context ---

PLAN_CONTEXT=$(gather_plan)
CHANGELOG_CONTEXT=$(gather_changelog)
GIT_CONTEXT=$(gather_git_context)
BEADS_CONTEXT=$(gather_beads)
TICKET_STATE=$(gather_ticket_state)
SESSION_TITLE=$(derive_title)

# Derive project/repo name
PROJECT_NAME=$(basename "$PROJECT_CWD")
REPO_NAME=""
if git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
    local_common=$(git -C "$PROJECT_CWD" rev-parse --git-common-dir 2>/dev/null || true)
    if [[ -n "$local_common" ]]; then
        REPO_NAME=$(cd "$PROJECT_CWD" && cd "$local_common/.." && basename "$(pwd)" 2>/dev/null || echo "$PROJECT_NAME")
    fi
fi
REPO_NAME="${REPO_NAME:-$PROJECT_NAME}"

# --- Eligibility Gate (Concern #4: require at least one real source) ---
# Instead of a brittle char-count threshold, require at least one of:
# plan.md, changelog, or branch-scoped git commits.

HAS_PLAN=false
HAS_CHANGELOG=false
HAS_GIT_COMMITS=false

[[ -n "$PLAN_CONTEXT" ]] && HAS_PLAN=true
[[ -n "$CHANGELOG_CONTEXT" ]] && HAS_CHANGELOG=true
if echo "$GIT_CONTEXT" | grep -q '^[a-f0-9]\{7,\} ' 2>/dev/null; then
    HAS_GIT_COMMITS=true
fi

if ! $HAS_PLAN && ! $HAS_CHANGELOG && ! $HAS_GIT_COMMITS; then
    echo -e "${YELLOW}No substantive session context found (need plan.md, changelog, or branch commits). Skipping.${NC}" >&2
    exit 0
fi

if $VERBOSE; then
    echo -e "${BLUE}=== Gathered Context ===${NC}"
    echo -e "Session ID: $SESSION_ID"
    echo -e "Title: $SESSION_TITLE"
    echo -e "Project: $PROJECT_NAME (repo: $REPO_NAME)"
    echo -e "Sources: plan=$HAS_PLAN changelog=$HAS_CHANGELOG git=$HAS_GIT_COMMITS"
    echo -e "Plan: $(echo "$PLAN_CONTEXT" | wc -l | tr -d ' ') lines"
    echo -e "Changelog: $(echo "$CHANGELOG_CONTEXT" | wc -l | tr -d ' ') lines"
    echo -e "Git: $(echo "$GIT_CONTEXT" | wc -l | tr -d ' ') lines"
    echo -e "Beads: $(echo "$BEADS_CONTEXT" | wc -l | tr -d ' ') lines"
    echo ""
fi

# --- Build Synthesis Prompt (Concern #3: scoped + redacted + size-capped) ---

# Assemble context, then truncate the whole prompt to MAX_PROMPT_BYTES
RAW_CONTEXT="## Available Context

### Plan (Living Document)
\`\`\`
${PLAN_CONTEXT:-No plan.md found}
\`\`\`

### Session Changelog
\`\`\`
${CHANGELOG_CONTEXT:-No changelog found}
\`\`\`

### Git Activity (current branch only)
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
\`\`\`"

CAPPED_CONTEXT=$(echo "$RAW_CONTEXT" | truncate_to "$MAX_PROMPT_BYTES")

SYNTHESIS_PROMPT="# Session Synthesis Task

You are synthesizing a Claude Code session into structured Obsidian documentation.
Generate a comprehensive session document in markdown format.

## Session Info
- **Date:** $TODAY
- **Session ID:** $SESSION_ID
- **Project:** $REPO_NAME
- **Title:** $SESSION_TITLE
- **Ticket:** ${TICKET_ID:-N/A}

${CAPPED_CONTEXT}

## Output Requirements

Generate ONLY the markdown content (no code fences wrapping the output). Structure:

1. **YAML Frontmatter** — MUST include these exact fields:
   - type: claude-session-synthesis
   - session_id: \"$SESSION_ID\"
   - date: \"$TODAY\"
   - project: \"$REPO_NAME\"
   - title: (descriptive title)
   - tags: [claude-session, project/$REPO_NAME]
   - ticket: \"${TICKET_ID:-null}\"
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
- Do NOT wrap the entire output in a code block
- Do NOT include any secrets, tokens, or credentials"

# --- Execute Synthesis ---

if $DRY_RUN; then
    echo -e "${BLUE}=== Synthesis Prompt (dry run) ===${NC}"
    echo "$SYNTHESIS_PROMPT"
    echo ""
    echo -e "${BLUE}Output would write to: $OUTPUT_FILE${NC}"
    exit 0
fi

echo -e "${BLUE}Synthesizing session to Obsidian (id: $SESSION_ID)...${NC}"

# Call claude for synthesis
SYNTHESIS_OUTPUT=""
if command -v claude &>/dev/null; then
    SYNTHESIS_OUTPUT=$(claude --print -p "$SYNTHESIS_PROMPT" 2>/dev/null) || {
        echo -e "${YELLOW}Claude synthesis call failed, falling back to template${NC}" >&2
        SYNTHESIS_OUTPUT=""
    }
fi

# Fallback: if claude unavailable or failed, generate a structured template
if [[ -z "$SYNTHESIS_OUTPUT" ]]; then
    # Extract objective from plan if available
    PLAN_OBJECTIVE=""
    if [[ -n "$PLAN_CONTEXT" ]]; then
        PLAN_OBJECTIVE=$(echo "$PLAN_CONTEXT" | sed -n '/^## Objective/,/^## /p' | head -10 | tail -n +2)
    fi

    SYNTHESIS_OUTPUT="---
type: \"claude-session-synthesis\"
session_id: \"$SESSION_ID\"
date: \"$TODAY\"
project: \"$REPO_NAME\"
title: \"$SESSION_TITLE\"
tags:
  - \"claude-session\"
  - \"project/$REPO_NAME\"
ticket: \"${TICKET_ID:-null}\"
status: \"completed\"
---

# Session: $SESSION_TITLE

## Objective

${PLAN_OBJECTIVE:-_No objective found in plan.md._}

## What Was Done

### Git Activity
${GIT_CONTEXT:-_No git context._}

### Issue Tracking
${BEADS_CONTEXT:-_No beads data._}

## Changelog
${CHANGELOG_CONTEXT:-_No changelog entries._}
"
fi

# --- Validate Output (Concern #4: verify required fields before writing) ---

validate_output() {
    local output="$1"

    # Must start with YAML frontmatter
    if [[ "$output" != ---* ]]; then
        echo "missing frontmatter delimiters" >&2
        return 1
    fi

    # Must contain required fields
    local missing=""
    for field in "type:" "session_id:" "date:" "project:" "title:"; do
        if ! echo "$output" | head -20 | grep -q "$field"; then
            missing="${missing} ${field}"
        fi
    done

    if [[ -n "$missing" ]]; then
        echo "missing required fields:${missing}" >&2
        return 1
    fi

    # Must have closing frontmatter delimiter (second ---)
    local delim_count
    delim_count=$(echo "$output" | head -25 | grep -c '^---$' || true)
    if [[ "$delim_count" -lt 2 ]]; then
        echo "frontmatter not closed" >&2
        return 1
    fi

    return 0
}

VALIDATION_ERROR=""
if ! VALIDATION_ERROR=$(validate_output "$SYNTHESIS_OUTPUT"); then
    echo -e "${YELLOW}Output validation failed (${VALIDATION_ERROR}), injecting required fields${NC}" >&2

    # Inject valid frontmatter wrapping the raw output
    SYNTHESIS_OUTPUT="---
type: \"claude-session-synthesis\"
session_id: \"$SESSION_ID\"
date: \"$TODAY\"
project: \"$REPO_NAME\"
title: \"$SESSION_TITLE\"
tags:
  - \"claude-session\"
  - \"project/$REPO_NAME\"
ticket: \"${TICKET_ID:-null}\"
status: \"completed\"
validation_repaired: true
---

${SYNTHESIS_OUTPUT}
"
fi

# --- Write Canonical Note (Concern #2: one canonical file, no fan-out copies) ---

echo "$SYNTHESIS_OUTPUT" >"$OUTPUT_FILE"
echo -e "${GREEN}Session synthesized: $OUTPUT_FILE${NC}"

# --- Add Wikilink in Project Folder (Concern #2: link, not copy) ---
# Instead of copying the file to multiple locations (which creates divergent
# duplicates), we add an Obsidian wikilink reference in the project's index.

add_project_link() {
    local project_dir="$1"
    local sessions_index="$project_dir/Sessions/_index.md"
    local note_basename
    note_basename=$(basename "$OUTPUT_FILE" .md)
    local link_line="- [[Claude/Sessions/${note_basename}|${SESSION_TITLE} ($TODAY)]]"

    mkdir -p "$project_dir/Sessions"

    # Create index if it doesn't exist
    if [[ ! -f "$sessions_index" ]]; then
        cat >"$sessions_index" <<EOF
---
type: session-index
project: $REPO_NAME
---

# Session Log

EOF
    fi

    # Check if link already exists (idempotent)
    if grep -qF "$note_basename" "$sessions_index" 2>/dev/null; then
        return
    fi

    echo "$link_line" >>"$sessions_index"
    echo -e "${GREEN}Linked in: $sessions_index${NC}"
}

# Link from top-level project folder if it exists in vault
PROJECT_VAULT_DIR="$OBSIDIAN_VAULT/$REPO_NAME"
if [[ -d "$PROJECT_VAULT_DIR" ]]; then
    add_project_link "$PROJECT_VAULT_DIR"
fi

# Link from Projects/ subfolder if it exists
PROJECTS_DIR="$OBSIDIAN_VAULT/Projects"
if [[ -d "$PROJECTS_DIR" ]]; then
    for proj_dir in "$PROJECTS_DIR"/*/; do
        proj_name=$(basename "$proj_dir")
        if [[ "${proj_name,,}" == "${REPO_NAME,,}" ]]; then
            add_project_link "$proj_dir"
            break
        fi
    done
fi

echo -e "${GREEN}Session synthesis complete (id: $SESSION_ID)${NC}"
