#!/usr/bin/env bash
#
# weekly-synthesis.sh - Generate weekly synthesis of Claude Code sessions into Obsidian
#
# Scans synthesized session files (matching *-synth-*.md) from the last 7 days,
# aggregates structured data (projects, tickets, decisions, lessons), then calls
# claude --print to produce natural-language prose. Falls back to a structured
# template when claude is unavailable or fails.
#
# Idempotent: if this week's output file already exists and has valid frontmatter,
# exits cleanly unless --force is given. Atomic writes via mktemp + mv.
#
# Usage:
#   weekly-synthesis.sh [OPTIONS]
#
# Options:
#   --force         Regenerate even if this week's file already exists
#   --week YYYY-Www Override the ISO week (default: current week via date +%G-W%V)
#   --verbose       Show aggregated data before synthesis
#   --dry-run       Print what would be done without writing
#   --help          Show this help

set -euo pipefail

# --- Configuration ---
OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/obsidian}"
SESSIONS_DIR="$OBSIDIAN_VAULT/Claude/Sessions"
WEEKLY_DIR="$OBSIDIAN_VAULT/Claude/Synthesis/weekly"
MAX_PROMPT_BYTES=40000

# --- Colours ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Defaults ---
FORCE=false
VERBOSE=false
DRY_RUN=false
WEEK_OVERRIDE=""

show_help() {
    cat <<'EOF'
weekly-synthesis.sh - Generate weekly Obsidian synthesis of Claude sessions

USAGE:
  weekly-synthesis.sh [OPTIONS]

OPTIONS:
  --force           Regenerate even if this week's file already exists
  --week YYYY-Www   Override target ISO week (e.g. 2026-W14)
  --dry-run         Print what would be done without writing
  --verbose         Show aggregated data before calling claude --print
  --help            Show this help

ENVIRONMENT:
  OBSIDIAN_VAULT    Path to Obsidian vault (default: ~/obsidian)

OUTPUT:
  ~/obsidian/Claude/Synthesis/weekly/YYYY-Www.md
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --force)
        FORCE=true
        shift
        ;;
    --week)
        WEEK_OVERRIDE="$2"
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

# --- Compute week identifiers ---
if [[ -n "$WEEK_OVERRIDE" ]]; then
    WEEK="$WEEK_OVERRIDE"
    # Validate format
    if ! echo "$WEEK" | grep -qE '^[0-9]{4}-W[0-9]{2}$'; then
        echo -e "${RED}Error: --week must be in format YYYY-Www (e.g. 2026-W15)${NC}" >&2
        exit 1
    fi
else
    WEEK=$(date +%G-W%V)
fi

# Extract year and week number for computing the date range
YEAR=$(echo "$WEEK" | cut -d'-' -f1)
WEEK_NUM=$(echo "$WEEK" | cut -d'-' -f2 | tr -d 'W')
WEEK_DISPLAY=$(echo "$WEEK_NUM" | sed 's/^0//') # strip leading zero for prose

# Compute Monday of the ISO week (portable: works on macOS with BSD date)
# ISO week 1 contains the first Thursday of the year.
# Algorithm: find Jan 4 of the year (always in W01), then jump to the right week.
compute_week_start() {
    local year="$1"
    local week_num="$2"
    # Jan 4 is always in ISO week 1. Find its Monday.
    local jan4_dow
    jan4_dow=$(date -j -f "%Y-%m-%d" "${year}-01-04" "+%u" 2>/dev/null || date -d "${year}-01-04" "+%u" 2>/dev/null || echo "1")
    # Days from Jan 4 to that week's Monday
    local days_back
    days_back=$((jan4_dow - 1))
    # Days from Jan 4 Monday to target week Monday
    local days_forward
    days_forward=$(((week_num - 1) * 7))
    # Total offset from Jan 4
    local total_offset
    total_offset=$((days_forward - days_back))
    # Compute the date (macOS BSD date syntax)
    if date -j -f "%Y-%m-%d" "${year}-01-04" "+%Y-%m-%d" &>/dev/null; then
        # BSD date (macOS)
        date -j -v "${total_offset}d" -f "%Y-%m-%d" "${year}-01-04" "+%Y-%m-%d" 2>/dev/null
    else
        # GNU date (Linux)
        date -d "${year}-01-04 + ${total_offset} days" "+%Y-%m-%d" 2>/dev/null
    fi
}

WEEK_START=$(compute_week_start "$YEAR" "$WEEK_NUM")
# Week end = start + 6 days
if date -j -f "%Y-%m-%d" "$WEEK_START" "+%Y-%m-%d" &>/dev/null; then
    WEEK_END=$(date -j -v +6d -f "%Y-%m-%d" "$WEEK_START" "+%Y-%m-%d" 2>/dev/null)
else
    WEEK_END=$(date -d "$WEEK_START + 6 days" "+%Y-%m-%d" 2>/dev/null)
fi

DATE_RANGE="${WEEK_START}/${WEEK_END}"

# --- Validate vault ---
if [[ ! -d "$OBSIDIAN_VAULT" ]]; then
    echo -e "${RED}Error: Obsidian vault not found at $OBSIDIAN_VAULT${NC}" >&2
    exit 1
fi

mkdir -p "$WEEKLY_DIR"
OUTPUT_FILE="$WEEKLY_DIR/${WEEK}.md"

# --- Utilities ---

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

# Validate output has minimal required frontmatter
validate_weekly_output() {
    local output="$1"
    if [[ "$output" != ---* ]]; then
        echo "missing opening ---" >&2
        return 1
    fi
    local missing=""
    for field in "type:" "week:" "date_range:"; do
        if ! echo "$output" | head -20 | grep -q "$field"; then
            missing="${missing} ${field}"
        fi
    done
    if [[ -n "$missing" ]]; then
        echo "missing fields:${missing}" >&2
        return 1
    fi
    local delim_count
    delim_count=$(echo "$output" | head -25 | grep -c '^---$' || true)
    if [[ "$delim_count" -lt 2 ]]; then
        echo "frontmatter not closed" >&2
        return 1
    fi
    if ! echo "$output" | tail -n +3 | grep -q '^#' 2>/dev/null; then
        echo "no headings in body" >&2
        return 1
    fi
    return 0
}

# --- Idempotency check ---
if [[ -f "$OUTPUT_FILE" ]] && ! $FORCE && ! $DRY_RUN; then
    existing=$(cat "$OUTPUT_FILE")
    if [[ -n "$existing" ]] && validate_weekly_output "$existing" 2>/dev/null; then
        echo -e "${YELLOW}Weekly synthesis already exists (valid): $OUTPUT_FILE${NC}"
        echo -e "${YELLOW}Use --force to regenerate.${NC}"
        exit 0
    else
        echo -e "${YELLOW}Existing file is corrupt or empty, will replace.${NC}"
    fi
fi

# --- Find input session files ---
# Use find with -mtime -7 (files modified within last 7 days).
# When --week is specified for a past week, also check file dates via name prefix.

find_session_files() {
    if [[ -n "$WEEK_OVERRIDE" ]]; then
        # For past weeks: find by filename date prefix (YYYY-MM-DD in week range)
        local files=()
        # shellcheck disable=SC2012
        while IFS= read -r -d '' f; do
            local fname
            fname=$(basename "$f")
            # Extract date prefix: e.g. 2026-04-07-synth-...
            local fdate
            fdate=$(echo "$fname" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
            if [[ -n "$fdate" ]] && [[ "$fdate" > "$WEEK_END" || "$fdate" < "$WEEK_START" ]]; then
                : # outside range — skip
            elif [[ -n "$fdate" ]]; then
                files+=("$f")
            fi
        done < <(find "$SESSIONS_DIR" -maxdepth 1 -name '*-synth-*.md' -type f -print0 2>/dev/null)
        printf '%s\n' "${files[@]}" 2>/dev/null || true
    else
        # Current week: find by mtime (last 7 days)
        find "$SESSIONS_DIR" -maxdepth 1 -name '*-synth-*.md' -type f -mtime -7 2>/dev/null
    fi
}

mapfile -t SESSION_FILES < <(find_session_files | sort)
SESSION_COUNT=${#SESSION_FILES[@]}

if $VERBOSE; then
    echo -e "${BLUE}Week: $WEEK (${WEEK_START} to ${WEEK_END})${NC}"
    echo -e "${BLUE}Sessions found: $SESSION_COUNT${NC}"
fi

# --- Aggregate structured data from session files ---

aggregate_frontmatter_field() {
    local field="$1"
    shift
    local files=("$@")
    local results=()
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        local val
        val=$(sed -n '1,/^---$/p' "$f" | tail -n +2 | { grep "^${field}:" || true; } | head -1 | sed "s/^${field}: *//" | tr -d '"' | tr -d "'")
        if [[ -n "$val" && "$val" != "null" && "$val" != "\"null\"" ]]; then
            results+=("$val")
        fi
    done
    # Deduplicate and return sorted
    printf '%s\n' "${results[@]}" | sort -u | tr '\n' ',' | sed 's/,$//'
}

aggregate_list_field() {
    # For YAML list fields like tags: [a, b, c]
    local field="$1"
    shift
    local files=("$@")
    local results=()
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        local val
        val=$(sed -n '1,/^---$/p' "$f" | tail -n +2 | { grep "^${field}:" || true; } | head -1 | sed "s/^${field}: *//" | tr -d '[]' | tr ',' '\n' | tr -d '"' | tr -d "'" | sed 's/^ *//;s/ *$//')
        if [[ -n "$val" ]]; then
            while IFS= read -r item; do
                [[ -n "$item" ]] && results+=("$item")
            done <<<"$val"
        fi
    done
    printf '%s\n' "${results[@]}" | sort -u | tr '\n' ',' | sed 's/,$//'
}

extract_section() {
    local section_header="$1"
    local file="$2"
    local max_lines="${3:-15}"
    # Extract content between this ## section and the next ##
    sed -n "/^${section_header}/,/^## /p" "$file" | grep -v '^## ' | head -"$max_lines" | sed '/^$/d' || true
}

# Aggregate projects (deduplicated list)
PROJECTS_CSV=$(aggregate_frontmatter_field "project" "${SESSION_FILES[@]+"${SESSION_FILES[@]}"}")

# Aggregate tickets (non-null, deduplicated)
TICKETS_CSV=$(aggregate_frontmatter_field "ticket" "${SESSION_FILES[@]+"${SESSION_FILES[@]}"}")
# Clean up: remove bare "null" entries
TICKETS_CSV=$(echo "$TICKETS_CSV" | tr ',' '\n' | grep -v '^null$' | sort -u | tr '\n' ',' | sed 's/,$//' || true)

# Build session wikilinks list
SESSION_LINKS=""
for f in "${SESSION_FILES[@]+"${SESSION_FILES[@]}"}"; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f" .md)
    # Try to get title from frontmatter
    title=$(sed -n '1,/^---$/p' "$f" | tail -n +2 | { grep '^title:' || true; } | head -1 | sed 's/^title: *//' | tr -d '"' | tr -d "'")
    date_prefix=$(echo "$fname" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
    project=$(sed -n '1,/^---$/p' "$f" | tail -n +2 | { grep '^project:' || true; } | head -1 | sed 's/^project: *//' | tr -d '"' | tr -d "'")
    if [[ -n "$title" ]]; then
        SESSION_LINKS="${SESSION_LINKS}- [[Claude/Sessions/${fname}|${title}]]"$'\n'
    else
        SESSION_LINKS="${SESSION_LINKS}- [[Claude/Sessions/${fname}|${date_prefix} — ${project}]]"$'\n'
    fi
done

# Collect Key Decisions across sessions (first 3 bullet/numbered items per session, capped)
KEY_DECISIONS_RAW=""
decision_file_count=0
for f in "${SESSION_FILES[@]+"${SESSION_FILES[@]}"}"; do
    [[ -f "$f" ]] || continue
    section=$(extract_section "## Key Decisions" "$f" 8)
    if [[ -n "$section" ]]; then
        fname=$(basename "$f" .md)
        project=$(sed -n '1,/^---$/p' "$f" | tail -n +2 | { grep '^project:' || true; } | head -1 | sed 's/^project: *//' | tr -d '"' | tr -d "'" || true)
        KEY_DECISIONS_RAW="${KEY_DECISIONS_RAW}### ${fname} (${project})"$'\n'"${section}"$'\n\n'
        decision_file_count=$((decision_file_count + 1))
        [[ $decision_file_count -ge 10 ]] && break
    fi
done

# Collect Lessons & Insights
LESSONS_RAW=""
lesson_file_count=0
for f in "${SESSION_FILES[@]+"${SESSION_FILES[@]}"}"; do
    [[ -f "$f" ]] || continue
    section=$(extract_section "## Lessons" "$f" 8)
    if [[ -n "$section" ]]; then
        fname=$(basename "$f" .md)
        project=$(sed -n '1,/^---$/p' "$f" | tail -n +2 | { grep '^project:' || true; } | head -1 | sed 's/^project: *//' | tr -d '"' | tr -d "'" || true)
        LESSONS_RAW="${LESSONS_RAW}### ${fname} (${project})"$'\n'"${section}"$'\n\n'
        lesson_file_count=$((lesson_file_count + 1))
        [[ $lesson_file_count -ge 10 ]] && break
    fi
done

# Convert CSV to YAML list syntax
csv_to_yaml_list() {
    local csv="$1"
    [[ -z "$csv" ]] && echo "  []" && return
    local result="["
    local first=true
    while IFS=',' read -ra items; do
        for item in "${items[@]}"; do
            item=$(echo "$item" | sed 's/^ *//;s/ *$//')
            [[ -z "$item" ]] && continue
            if $first; then
                result="${result}${item}"
                first=false
            else
                result="${result}, ${item}"
            fi
        done
    done <<<"$csv"
    echo "${result}]"
}

PROJECTS_YAML=$(csv_to_yaml_list "$PROJECTS_CSV")
TICKETS_YAML=$(csv_to_yaml_list "$TICKETS_CSV")

if $VERBOSE; then
    echo -e "${BLUE}Projects: $PROJECTS_CSV${NC}"
    echo -e "${BLUE}Tickets: $TICKETS_CSV${NC}"
    echo -e "${BLUE}Sessions with decisions: $decision_file_count${NC}"
    echo -e "${BLUE}Sessions with lessons: $lesson_file_count${NC}"
fi

# --- Handle zero sessions ---
if [[ $SESSION_COUNT -eq 0 ]]; then
    if $DRY_RUN; then
        echo -e "${YELLOW}No session files found for $WEEK — would write empty weekly stub.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}No synthesized session files found for $WEEK.${NC}"
    echo -e "${YELLOW}Searched: $SESSIONS_DIR (pattern: *-synth-*.md, week: ${WEEK_START}..${WEEK_END})${NC}"
    # Write a minimal stub so the week is represented
    FALLBACK_OUTPUT="---
type: weekly-synthesis
week: \"${WEEK}\"
date_range: \"${DATE_RANGE}\"
sessions_count: 0
projects: []
tickets: []
tags:
  - claude-synthesis
  - synthesis/weekly
---

# Week ${WEEK_DISPLAY} of ${YEAR}

No synthesized session files found for this week (${WEEK_START} to ${WEEK_END}).
"
    TEMP_FILE=$(mktemp "${WEEKLY_DIR}/.weekly-XXXXXX.md")
    echo "$FALLBACK_OUTPUT" >"$TEMP_FILE"
    mv -f "$TEMP_FILE" "$OUTPUT_FILE"
    echo -e "${GREEN}Wrote empty stub: $OUTPUT_FILE${NC}"
    exit 0
fi

# --- Build synthesis prompt ---

AGGREGATED_DATA="## Aggregated Session Data

**Week:** ${WEEK} (${WEEK_START} to ${WEEK_END})
**Sessions:** ${SESSION_COUNT}
**Projects worked on:** ${PROJECTS_CSV:-none}
**Tickets touched:** ${TICKETS_CSV:-none}

---

### Session List
${SESSION_LINKS:-_No sessions_}

---

### Key Decisions (sampled from sessions with that section)

${KEY_DECISIONS_RAW:-_No Key Decisions sections found in sessions._}

---

### Lessons & Insights (sampled from sessions with that section)

${LESSONS_RAW:-_No Lessons sections found in sessions._}
"

CAPPED_DATA=$(echo "$AGGREGATED_DATA" | truncate_to "$MAX_PROMPT_BYTES")

SYNTHESIS_PROMPT="# Weekly Synthesis Task

You are generating a weekly synthesis document for an Obsidian knowledge base.
This covers a Claude Code session archive following Karpathy's Living Knowledge Base pattern.

${CAPPED_DATA}

## Output Requirements

Generate ONLY valid markdown (no wrapping code fences). The document must begin with YAML frontmatter.

Required frontmatter fields (output these EXACTLY):
\`\`\`
---
type: weekly-synthesis
week: \"${WEEK}\"
date_range: \"${DATE_RANGE}\"
sessions_count: ${SESSION_COUNT}
projects: ${PROJECTS_YAML}
tickets: ${TICKETS_YAML}
tags:
  - claude-synthesis
  - synthesis/weekly
---
\`\`\`

Then write these sections:

# Week ${WEEK_DISPLAY} of ${YEAR}

## Summary
2-4 paragraph narrative: what was the dominant theme of work this week? Which projects had the most momentum? What kinds of problems were being solved?

## Sessions
List all sessions from the session list above as Obsidian wikilinks.

## Key Decisions
Synthesize the most important decisions made this week across all sessions. Focus on decisions with lasting architectural or workflow consequences. Keep it to 5-10 bullets maximum.

## Lessons
The most transferable insights from this week. Things worth remembering for future sessions. 5-10 bullets max.

## Rules
- Be specific and concrete — reference project names, patterns you see
- If sessions span very different domains, note the context-switching
- Do NOT fabricate details not in the aggregated data
- Do NOT wrap output in a code block
- Keep the whole document under 600 lines"

# --- Dry run ---
if $DRY_RUN; then
    echo -e "${BLUE}=== Dry Run ===${NC}"
    echo -e "Week: $WEEK"
    echo -e "Date range: $DATE_RANGE"
    echo -e "Sessions found: $SESSION_COUNT"
    echo -e "Projects: $PROJECTS_CSV"
    echo -e "Tickets: $TICKETS_CSV"
    echo -e "Output would be: $OUTPUT_FILE"
    echo ""
    echo -e "${BLUE}--- Synthesis prompt (first 80 lines) ---${NC}"
    echo "$SYNTHESIS_PROMPT" | head -80
    exit 0
fi

# --- Execute synthesis ---
echo -e "${BLUE}Generating weekly synthesis for $WEEK ($SESSION_COUNT sessions)...${NC}"

SYNTHESIS_OUTPUT=""
if command -v claude &>/dev/null; then
    # Run claude in a subshell with errors suppressed so failures never propagate
    # to the outer set -e context. Capture output; empty string triggers fallback.
    _claude_out=""
    _claude_rc=0
    _claude_out=$(
        set +e
        claude --print -p "$SYNTHESIS_PROMPT" 2>/dev/null
        echo "rc:$?"
    ) || _claude_rc=1
    # Extract the real output (everything before the trailing rc: line)
    _claude_rc_line=$(echo "$_claude_out" | tail -1)
    _claude_out=$(echo "$_claude_out" | head -n -1)
    if echo "$_claude_rc_line" | grep -q "^rc:0$" && [[ -n "$_claude_out" ]]; then
        SYNTHESIS_OUTPUT="$_claude_out"
    else
        echo -e "${YELLOW}claude --print failed or returned empty, using fallback template${NC}" >&2
    fi
else
    echo -e "${YELLOW}claude not found in PATH, using fallback template${NC}" >&2
fi

# --- Fallback template ---
if [[ -z "$SYNTHESIS_OUTPUT" ]]; then
    SYNTHESIS_OUTPUT="---
type: weekly-synthesis
week: \"${WEEK}\"
date_range: \"${DATE_RANGE}\"
sessions_count: ${SESSION_COUNT}
projects: ${PROJECTS_YAML}
tickets: ${TICKETS_YAML}
tags:
  - claude-synthesis
  - synthesis/weekly
---

# Week ${WEEK_DISPLAY} of ${YEAR}

## Summary

${SESSION_COUNT} sessions synthesized across projects: ${PROJECTS_CSV:-none}.
${TICKETS_CSV:+Tickets touched: ${TICKETS_CSV}.}
_(Claude prose unavailable — raw aggregated data below)_

## Sessions

${SESSION_LINKS:-_No sessions._}

## Key Decisions

${KEY_DECISIONS_RAW:-_No Key Decisions sections extracted._}

## Lessons

${LESSONS_RAW:-_No Lessons sections extracted._}
"
fi

# --- Validate + repair frontmatter ---
VALIDATION_ERR=""
if ! VALIDATION_ERR=$(validate_weekly_output "$SYNTHESIS_OUTPUT" 2>&1); then
    echo -e "${YELLOW}Validation failed (${VALIDATION_ERR}), prepending frontmatter${NC}" >&2
    SYNTHESIS_OUTPUT="---
type: weekly-synthesis
week: \"${WEEK}\"
date_range: \"${DATE_RANGE}\"
sessions_count: ${SESSION_COUNT}
projects: ${PROJECTS_YAML}
tickets: ${TICKETS_YAML}
tags:
  - claude-synthesis
  - synthesis/weekly
validation_repaired: true
---

${SYNTHESIS_OUTPUT}"
fi

# --- Atomic write ---
TEMP_FILE=$(mktemp "${WEEKLY_DIR}/.weekly-XXXXXX.md")
echo "$SYNTHESIS_OUTPUT" >"$TEMP_FILE"
mv -f "$TEMP_FILE" "$OUTPUT_FILE"
echo -e "${GREEN}Weekly synthesis written: $OUTPUT_FILE${NC}"
