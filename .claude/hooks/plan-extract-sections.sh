#!/usr/bin/env bash
# plan-extract-sections.sh - Extract key sections from .claude/plan.md
#
# Shared helper for plan hooks. Extracts only the sections needed for
# context recovery: Current State, Next Steps, Useful Commands.
# Keeps injected context small regardless of total plan size.
#
# Usage: bash plan-extract-sections.sh /path/to/plan.md

set -euo pipefail

PLAN_FILE="${1:-}"
[[ -f "$PLAN_FILE" ]] || exit 0

# Extract content between ## headings using awk
# Captures: Current State, Next Steps, Useful Commands
extract_section() {
    local section="$1" file="$2"
    awk -v sec="## $section" '
        $0 == sec { found=1; print; next }
        found && /^## / { exit }
        found { print }
    ' "$file"
}

CURRENT=$(extract_section "Current State" "$PLAN_FILE")
NEXT=$(extract_section "Next Steps" "$PLAN_FILE")
COMMANDS=$(extract_section "Useful Commands" "$PLAN_FILE")

# Only output sections that have real content (not just headings, blanks, or _placeholder_ lines)
has_content() {
    local text="$1"
    # Strip heading lines, blank lines, and italic placeholder lines (_..._)
    local real
    real=$(echo "$text" | grep -v '^\(## \|[[:space:]]*$\)' | grep -v '^_.*_$' 2>/dev/null)
    [[ -n "$real" ]]
}

OUTPUT=""

if has_content "$CURRENT"; then
    OUTPUT="${OUTPUT}${CURRENT}
"
fi

if has_content "$NEXT"; then
    OUTPUT="${OUTPUT}${NEXT}
"
fi

if has_content "$COMMANDS"; then
    OUTPUT="${OUTPUT}${COMMANDS}
"
fi

# Only output if we have something meaningful
if [[ -n "$OUTPUT" ]]; then
    echo "$OUTPUT"
fi

exit 0
