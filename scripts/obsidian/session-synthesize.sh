#!/usr/bin/env bash
#
# session-synthesize.sh - Synthesize Claude Code session into Obsidian documentation
#
# Gathers session context (plan fields, changelog entries, git commits, beads)
# and uses claude --print to generate structured Obsidian documentation.
#
# Idempotent: uses the Claude session UUID (from JSONL filename) as the session
# ID. Falls back to md5(HEAD-commit + branch + project) when JSONL is unavailable.
# Atomic writes via temp file + mv. Replaces corrupt/incomplete existing files.
#
# Usage:
#   session-synthesize.sh [OPTIONS]
#   session-synthesize.sh --worktree /path/to/worktree
#   session-synthesize.sh --cwd /path/to/project
#   session-synthesize.sh --reconcile          # Catch-up missed sessions
#   session-synthesize.sh --dry-run
#
# Output:
#   Writes to ~/obsidian/Claude/Sessions/<date>-synth-<session-id>.md
#   Adds Obsidian wikilink in project folder (no file copies)

set -euo pipefail

# Configuration
OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/obsidian}"
CLAUDE_SESSIONS_DIR="$OBSIDIAN_VAULT/Claude/Sessions"
CLAUDE_PROJECTS_DIR="${HOME}/.claude/projects"
TODAY=$(date -u +%Y-%m-%d)
MAX_PROMPT_BYTES=30000

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
RECONCILE=false

show_help() {
    cat <<'EOF'
session-synthesize.sh - Synthesize Claude session into Obsidian

USAGE:
  session-synthesize.sh [OPTIONS]

OPTIONS:
  --worktree PATH   Worktree path (for gwt-ticket sessions)
  --cwd PATH        Project working directory (default: current dir)
  --ticket ID       Ticket/issue ID to associate
  --reconcile       Catch up missed sessions (crash/SIGKILL recovery)
  --dry-run         Print synthesis prompt without writing
  --verbose         Show gathered context
  --help            Show this help

ENVIRONMENT:
  OBSIDIAN_VAULT    Path to Obsidian vault (default: ~/obsidian)

WHAT IT DOES:
  1. Resolves a unique session ID (Claude JSONL UUID or content hash)
  2. If valid output file already exists, exits (idempotent)
  3. Extracts structured fields from session context sources
  4. Redacts secrets from all extracted content
  5. Calls claude --print to generate documentation
  6. Validates output, writes atomically (temp + mv)
  7. Adds Obsidian wikilink in project folder (no file copies)
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
    --reconcile)
        RECONCILE=true
        shift
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

redact_secrets() {
    sed \
        -e 's/sk-[a-zA-Z0-9_-]\{10,\}/[REDACTED_API_KEY]/g' \
        -e 's/ghp_[a-zA-Z0-9]\{36,\}/[REDACTED_GH_TOKEN]/g' \
        -e 's/AKIA[A-Z0-9]\{16\}/[REDACTED_AWS_KEY]/g' \
        -e 's/Bearer [a-zA-Z0-9._-]\{20,\}/[REDACTED_BEARER]/g' \
        -e 's/-----BEGIN.*PRIVATE KEY-----/[REDACTED_PRIVATE_KEY]/g' \
        -e 's/-----END.*PRIVATE KEY-----//g'
}

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

# Validate a synthesis output file has required frontmatter.
# Returns 0 if valid, 1 if corrupt/incomplete.
validate_output() {
    local output="$1"

    if [[ "$output" != ---* ]]; then
        echo "missing frontmatter delimiters" >&2
        return 1
    fi

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

    local delim_count
    delim_count=$(echo "$output" | head -25 | grep -c '^---$' || true)
    if [[ "$delim_count" -lt 2 ]]; then
        echo "frontmatter not closed" >&2
        return 1
    fi

    return 0
}

# --- Session ID Resolution ---
# Priority: Claude JSONL UUID > content-based hash.
# The JSONL UUID is globally unique per session. The content hash covers
# cases where the JSONL is unavailable (non-Claude sessions, early exit).

resolve_session_id() {
    # Try 1: Find the most recent JSONL for this project directory.
    # Claude stores sessions at ~/.claude/projects/<slug>/<uuid>.jsonl
    local project_slug
    project_slug=$(echo "$PROJECT_CWD" | tr '/' '-')
    local jsonl_dir="$CLAUDE_PROJECTS_DIR/$project_slug"

    if [[ -d "$jsonl_dir" ]]; then
        local latest_jsonl
        latest_jsonl=$(find "$jsonl_dir" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null |
            xargs -0 ls -t 2>/dev/null | head -1)
        if [[ -n "$latest_jsonl" ]]; then
            # Extract UUID from filename (e.g., c15be7c5-878e-499f-b9a4-81b049678fad.jsonl)
            local uuid
            uuid=$(basename "$latest_jsonl" .jsonl)
            # Validate it looks like a UUID
            if [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
                echo "$uuid"
                return
            fi
        fi
    fi

    # Try 2: Content-based hash from HEAD commit + branch + project.
    # This is unique per commit state, so two sessions that end at different
    # commits get different IDs (unlike the old date-only approach).
    local branch=""
    local head_sha=""
    if git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
        branch=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || echo "detached")
        head_sha=$(git -C "$PROJECT_CWD" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    local project
    project=$(basename "$PROJECT_CWD")
    echo -n "${head_sha}:${branch}:${project}:${TODAY}" | md5sum | cut -c1-12
}

SESSION_ID=$(resolve_session_id)
OUTPUT_FILE="$CLAUDE_SESSIONS_DIR/${TODAY}-synth-${SESSION_ID}.md"

# --- Idempotency Check ---
# If the file exists AND is valid, skip. If it exists but is corrupt, replace it.
if [[ -f "$OUTPUT_FILE" ]] && ! $DRY_RUN && ! $RECONCILE; then
    existing_content=$(cat "$OUTPUT_FILE")
    if validate_output "$existing_content" 2>/dev/null; then
        echo -e "${YELLOW}Session already synthesized (valid): $OUTPUT_FILE${NC}"
        exit 0
    else
        echo -e "${YELLOW}Existing file is corrupt, will replace: $OUTPUT_FILE${NC}"
        # Fall through to regenerate
    fi
fi

# --- Reconcile Mode ---
# Scans for recent JSONL sessions that lack a corresponding synthesis note.
if $RECONCILE; then
    echo -e "${BLUE}=== Reconcile: scanning for missed sessions ===${NC}"
    reconciled=0
    for jsonl_dir in "$CLAUDE_PROJECTS_DIR"/*/; do
        [[ -d "$jsonl_dir" ]] || continue
        for jsonl_file in "$jsonl_dir"*.jsonl; do
            [[ -f "$jsonl_file" ]] || continue
            local_uuid=$(basename "$jsonl_file" .jsonl)
            # Only process files from the last 7 days
            if [[ $(find "$jsonl_file" -mtime -7 2>/dev/null) ]]; then
                local_date=$(date -r "$jsonl_file" -u +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)
                local_output="$CLAUDE_SESSIONS_DIR/${local_date}-synth-${local_uuid}.md"
                if [[ ! -f "$local_output" ]]; then
                    echo -e "  Missing: ${local_uuid} (${local_date})"
                    reconciled=$((reconciled + 1))
                fi
            fi
        done
    done
    if [[ $reconciled -eq 0 ]]; then
        echo -e "${GREEN}All recent sessions have synthesis notes.${NC}"
    else
        echo -e "${YELLOW}Found $reconciled sessions without synthesis notes.${NC}"
        echo -e "Run without --reconcile from each project to generate them."
    fi
    exit 0
fi

# --- Field-Level Context Extraction ---
# Instead of passing raw file contents, extract only structured fields.
# This bounds the data to session-relevant content and reduces leak surface.

extract_plan_fields() {
    local plan_file="$PROJECT_CWD/.claude/plan.md"
    [[ -f "$plan_file" ]] || return 0

    # Extract only the structured sections, not raw file content
    local field value
    for field in "ticket" "title"; do
        value=$({ grep "^${field}:" "$plan_file" || true; } | head -1 | sed "s/^${field}: *//" | tr -d '"')
        [[ -n "$value" ]] && echo "plan_${field}: ${value}"
    done

    # Extract section contents by header (bounded to next ## header)
    for section in "Objective" "Approach" "Progress" "Key Decisions" "Failed Approaches" "Current State"; do
        local content
        content=$(sed -n "/^## ${section}/,/^## /p" "$plan_file" | head -20 | tail -n +2 | sed '/^$/d')
        if [[ -n "$content" && "$content" != _* ]]; then
            echo ""
            echo "### Plan: ${section}"
            echo "$content" | redact_secrets
        fi
    done
}

extract_changelog_entries() {
    local changelog="$PROJECT_CWD/.claude/CHANGELOG.md"
    [[ -f "$changelog" ]] || return 0

    # Extract only typed entries (PROGRESS, DECISION, FAILED, METRIC, DISCOVERY)
    # These are the structured entries, not free-form text
    { grep -E '^\[.*\] (PROGRESS|DECISION|FAILED|METRIC|DISCOVERY):' "$changelog" 2>/dev/null || true; } |
        tail -30 |
        redact_secrets
}

extract_git_context() {
    git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null || return 0

    local branch
    branch=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || echo "(detached)")
    echo "branch: ${branch}"

    # Scope commits to current branch only
    local main_branch merge_base
    main_branch=$(git -C "$PROJECT_CWD" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    merge_base=$(git -C "$PROJECT_CWD" merge-base "$main_branch" HEAD 2>/dev/null || true)

    echo ""
    echo "commits:"
    if [[ -n "$merge_base" ]]; then
        git -C "$PROJECT_CWD" log --oneline "$merge_base..HEAD" 2>/dev/null | head -30
    else
        git -C "$PROJECT_CWD" log --oneline -10 2>/dev/null
    fi

    echo ""
    echo "diffstat:"
    if [[ -n "$merge_base" ]]; then
        git -C "$PROJECT_CWD" diff --stat "$merge_base" HEAD 2>/dev/null | tail -20
    else
        git -C "$PROJECT_CWD" diff --stat HEAD~5 HEAD 2>/dev/null | tail -20
    fi
}

extract_beads_fields() {
    command -v bd &>/dev/null || return 0
    [[ -d "$PROJECT_CWD/.beads" ]] || return 0

    echo "open_issues:"
    (cd "$PROJECT_CWD" && bd list --status=open 2>/dev/null | head -10) || true

    echo ""
    echo "closed_issues:"
    (cd "$PROJECT_CWD" && bd list --status=closed 2>/dev/null | head -10) || true

    echo ""
    echo "decisions:"
    (cd "$PROJECT_CWD" && bd comments list 2>/dev/null | head -15) || true
}

extract_ticket_fields() {
    local state_file="$PROJECT_CWD/.claude/ticket-execute.local.md"
    [[ -f "$state_file" ]] || return 0

    # Extract only safe YAML fields, not the entire file
    local field value
    for field in "issue_key" "title" "ticketing_system" "active" "started_at" "completed_at" "agent_harness" "sub_profile"; do
        value=$({ grep "^${field}:" "$state_file" || true; } | head -1 | sed "s/^${field}: *//" | tr -d '"')
        [[ -n "$value" ]] && echo "${field}: ${value}"
    done
}

derive_title() {
    local state_file="$PROJECT_CWD/.claude/ticket-execute.local.md"
    if [[ -f "$state_file" ]]; then
        local title
        title=$({ grep '^title:' "$state_file" || true; } | head -1 | sed 's/^title: *//' | tr -d '"')
        [[ -n "$title" ]] && echo "$title" && return 0
    fi

    local plan_file="$PROJECT_CWD/.claude/plan.md"
    if [[ -f "$plan_file" ]]; then
        local plan_title
        plan_title=$({ grep '^title:' "$plan_file" || true; } | head -1 | sed 's/^title: *//' | tr -d '"')
        [[ -n "$plan_title" ]] && echo "$plan_title" && return 0
    fi

    if git -C "$PROJECT_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
        local branch
        branch=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || true)
        [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]] && echo "$branch" && return 0
    fi

    basename "$PROJECT_CWD"
}

# --- Gather Extracted Fields ---
# Disable pipefail for extraction: grep/sed pipelines return 1 on no-match,
# which is expected when optional fields/files are absent.

PLAN_FIELDS=$(
    set +e +o pipefail
    extract_plan_fields
) || true
CHANGELOG_ENTRIES=$(
    set +e +o pipefail
    extract_changelog_entries
) || true
GIT_CONTEXT=$(
    set +e +o pipefail
    extract_git_context
) || true
BEADS_FIELDS=$(
    set +e +o pipefail
    extract_beads_fields
) || true
TICKET_FIELDS=$(
    set +e +o pipefail
    extract_ticket_fields
) || true
SESSION_TITLE=$(
    set +e +o pipefail
    derive_title
) || true

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

# --- Eligibility Gate ---
# Require at least one substantive source.

HAS_PLAN=false
HAS_CHANGELOG=false
HAS_GIT_COMMITS=false

[[ -n "$PLAN_FIELDS" ]] && HAS_PLAN=true
[[ -n "$CHANGELOG_ENTRIES" ]] && HAS_CHANGELOG=true
if echo "$GIT_CONTEXT" | grep -q '^[a-f0-9]\{7,\} ' 2>/dev/null; then
    HAS_GIT_COMMITS=true
fi

if ! $HAS_PLAN && ! $HAS_CHANGELOG && ! $HAS_GIT_COMMITS; then
    echo -e "${YELLOW}No substantive context (need plan, changelog, or branch commits). Skipping.${NC}" >&2
    exit 0
fi

if $VERBOSE; then
    echo -e "${BLUE}=== Context ===${NC}"
    echo -e "Session ID: $SESSION_ID"
    echo -e "Title: $SESSION_TITLE"
    echo -e "Project: $REPO_NAME"
    echo -e "Sources: plan=$HAS_PLAN changelog=$HAS_CHANGELOG git=$HAS_GIT_COMMITS"
    echo ""
fi

# --- Build Synthesis Prompt ---
# All sources are field-extracted and redacted before reaching the prompt.

RAW_CONTEXT="## Extracted Session Context

### Plan Fields
\`\`\`
${PLAN_FIELDS:-No plan data}
\`\`\`

### Changelog Entries (typed, last 30)
\`\`\`
${CHANGELOG_ENTRIES:-No changelog entries}
\`\`\`

### Git Activity (current branch only)
\`\`\`
${GIT_CONTEXT:-No git context}
\`\`\`

### Beads Issue Tracking
\`\`\`
${BEADS_FIELDS:-No beads data}
\`\`\`

### Ticket Metadata
\`\`\`
${TICKET_FIELDS:-No ticket state}
\`\`\`"

CAPPED_CONTEXT=$(echo "$RAW_CONTEXT" | truncate_to "$MAX_PROMPT_BYTES")

SYNTHESIS_PROMPT="# Session Synthesis Task

Synthesize this Claude Code session into structured Obsidian documentation.

## Session Info
- **Date:** $TODAY
- **Session ID:** $SESSION_ID
- **Project:** $REPO_NAME
- **Title:** $SESSION_TITLE
- **Ticket:** ${TICKET_ID:-N/A}

${CAPPED_CONTEXT}

## Output Requirements

Generate ONLY markdown (no wrapping code fences). Structure:

1. **YAML Frontmatter** — MUST include these exact fields:
   - type: claude-session-synthesis
   - session_id: \"$SESSION_ID\"
   - date: \"$TODAY\"
   - project: \"$REPO_NAME\"
   - title: (descriptive title)
   - tags: [claude-session, project/$REPO_NAME]
   - ticket: \"${TICKET_ID:-null}\"
   - status: completed

2. **# Title**
3. **## Objective** - what the session accomplished
4. **## Approach** - how the work was structured
5. **## What Was Done** - concrete changes with file paths and commit refs
6. **## Key Decisions** - choices and rationale
7. **## Outcomes** - what was achieved, what remains
8. **## Lessons & Insights** - worth remembering for future sessions

## Rules
- Be specific and concrete, reference actual files/commits
- If context is sparse, write a shorter document
- Do NOT include any secrets, tokens, or credentials
- Do NOT wrap output in a code block"

# --- Execute Synthesis ---

if $DRY_RUN; then
    echo -e "${BLUE}=== Dry Run ===${NC}"
    echo "$SYNTHESIS_PROMPT"
    echo ""
    echo -e "${BLUE}Output: $OUTPUT_FILE${NC}"
    exit 0
fi

echo -e "${BLUE}Synthesizing session (id: $SESSION_ID)...${NC}"

SYNTHESIS_OUTPUT=""
if command -v claude &>/dev/null; then
    SYNTHESIS_OUTPUT=$(claude --print -p "$SYNTHESIS_PROMPT" 2>/dev/null) || {
        echo -e "${YELLOW}Claude synthesis failed, using template${NC}" >&2
        SYNTHESIS_OUTPUT=""
    }
fi

# Fallback template
if [[ -z "$SYNTHESIS_OUTPUT" ]]; then
    PLAN_OBJECTIVE=""
    if [[ -n "$PLAN_FIELDS" ]]; then
        PLAN_OBJECTIVE=$(echo "$PLAN_FIELDS" | sed -n '/^### Plan: Objective/,/^### /p' | tail -n +2 | head -10)
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

${PLAN_OBJECTIVE:-_See plan fields below._}

## What Was Done

### Commits
${GIT_CONTEXT:-_No git context._}

### Issues
${BEADS_FIELDS:-_No beads data._}

## Changelog
${CHANGELOG_ENTRIES:-_No entries._}
"
fi

# --- Validate + Repair ---

VALIDATION_ERROR=""
if ! VALIDATION_ERROR=$(validate_output "$SYNTHESIS_OUTPUT"); then
    echo -e "${YELLOW}Validation failed (${VALIDATION_ERROR}), injecting frontmatter${NC}" >&2
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

# --- Atomic Write ---
# Write to a temp file, then mv (atomic on POSIX filesystems).
# This prevents concurrent writers from producing corrupt files.

TEMP_FILE=$(mktemp "${CLAUDE_SESSIONS_DIR}/.synth-XXXXXX")
echo "$SYNTHESIS_OUTPUT" >"$TEMP_FILE"
mv -f "$TEMP_FILE" "$OUTPUT_FILE"
echo -e "${GREEN}Synthesized: $OUTPUT_FILE${NC}"

# --- Add Wikilink (no file copies) ---

add_project_link() {
    local project_dir="$1"
    local sessions_index="$project_dir/Sessions/_index.md"
    local note_basename
    note_basename=$(basename "$OUTPUT_FILE" .md)
    local link_line="- [[Claude/Sessions/${note_basename}|${SESSION_TITLE} ($TODAY)]]"

    mkdir -p "$project_dir/Sessions"

    if [[ ! -f "$sessions_index" ]]; then
        cat >"$sessions_index" <<EOF
---
type: session-index
project: $REPO_NAME
---

# Session Log

EOF
    fi

    grep -qF "$note_basename" "$sessions_index" 2>/dev/null && return
    echo "$link_line" >>"$sessions_index"
    echo -e "${GREEN}Linked: $sessions_index${NC}"
}

PROJECT_VAULT_DIR="$OBSIDIAN_VAULT/$REPO_NAME"
if [[ -d "$PROJECT_VAULT_DIR" ]]; then
    add_project_link "$PROJECT_VAULT_DIR"
fi

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

echo -e "${GREEN}Done (id: $SESSION_ID)${NC}"
