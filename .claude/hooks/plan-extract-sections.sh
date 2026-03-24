#!/usr/bin/env bash
# plan-extract-sections.sh - Extract key sections from .claude/plan.md
#
# Shared helper for plan hooks. Extracts only the sections needed for
# context recovery: Failed Approaches, Current State, Next Steps, Useful Commands.
# Keeps injected context small regardless of total plan size.
#
# Usage: bash plan-extract-sections.sh /path/to/plan.md
#
# Handles: (#7) caps Useful Commands at last 10 entries
#          (#8) fuzzy-matches section headers (case-insensitive, common variations)

set -euo pipefail

PLAN_FILE="${1:-}"
[[ -f "$PLAN_FILE" ]] || exit 0

# Extract content between ## headings using awk
# Fuzzy match: case-insensitive, supports common variations
extract_section() {
    local file="$1"
    shift
    # Accept multiple patterns — first match wins
    local patterns=("$@")
    awk -v patterns="${patterns[*]}" '
        BEGIN {
            n = split(patterns, pats, " ")
        }
        /^## / {
            if (found) exit
            line = tolower($0)
            gsub(/^## /, "", line)
            for (i = 1; i <= n; i++) {
                if (index(line, pats[i]) > 0) {
                    found = 1
                    print
                    next
                }
            }
        }
        found { print }
    ' "$file"
}

# (#8) Fuzzy match common variations of section names
FAILED=$(extract_section "$PLAN_FILE" "failed approaches" "failed" "dead ends" "dead-ends" "what didn't work" "didn't work" "tried and failed")
CURRENT=$(extract_section "$PLAN_FILE" "current state" "current status" "state" "status" "where we are")
NEXT=$(extract_section "$PLAN_FILE" "next steps" "next" "todo" "remaining" "what's next")
COMMANDS=$(extract_section "$PLAN_FILE" "useful commands" "commands" "useful scripts" "recipes")

# Only output sections that have real content (not just headings, blanks, or _placeholder_ lines)
has_content() {
    local text="$1"
    local real
    real=$(echo "$text" | grep -v '^\(## \|[[:space:]]*$\)' | grep -v '^_.*_$' 2>/dev/null)
    [[ -n "$real" ]]
}

OUTPUT=""

# Failed Approaches first — dead-end prevention is highest priority for compaction survival
if has_content "$FAILED"; then
    OUTPUT="${OUTPUT}${FAILED}
"
fi

if has_content "$CURRENT"; then
    OUTPUT="${OUTPUT}${CURRENT}
"
fi

if has_content "$NEXT"; then
    OUTPUT="${OUTPUT}${NEXT}
"
fi

# (#7) Cap Useful Commands at last 10 code blocks
if has_content "$COMMANDS"; then
    # Count code blocks (``` pairs)
    BLOCK_COUNT=$(echo "$COMMANDS" | grep -c '^```' 2>/dev/null || echo "0")
    ENTRY_COUNT=$((BLOCK_COUNT / 2))

    if [[ "$ENTRY_COUNT" -gt 10 ]]; then
        # Keep heading + last 10 code blocks (20 ``` lines worth)
        HEADING=$(echo "$COMMANDS" | head -1)
        # Extract last 10 blocks: find line numbers of opening ```, take last 10
        OPENERS=$(echo "$COMMANDS" | grep -n '^```' | tail -20 | head -1 | cut -d: -f1)
        OUTPUT="${OUTPUT}${HEADING}
(showing last 10 of ${ENTRY_COUNT} saved commands)
$(echo "$COMMANDS" | tail -n +"$OPENERS")
"
    else
        OUTPUT="${OUTPUT}${COMMANDS}
"
    fi
fi

if [[ -n "$OUTPUT" ]]; then
    echo "$OUTPUT"
fi

exit 0
