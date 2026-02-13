#!/usr/bin/env bash
# Plan Structure Validator - validates markdown plan against DQS required sections
#
# Usage: plan-validate.sh <plan.md> [--strict]
#   --strict: also check optional sections
#
# Exit codes:
#   0: all required sections present
#   1: missing sections (printed to stderr)
#   2: no file provided or file not found
set -euo pipefail

if [ -z "${1:-}" ] || [ ! -f "$1" ]; then
    echo "Usage: plan-validate.sh <plan.md> [--strict]" >&2
    echo "Validates plan structure against DQS required sections." >&2
    exit 2
fi

plan_file="$1"
strict="${2:-}"

# Required sections (case-insensitive heading match)
required_sections=(
    "summary"
    "goals"
    "non.goals"
    "current.state"
    "proposed.*(approach|architecture|design)"
    "migration.strategy"
    "risks?.*(and|&).*mitigations?"
    "(architectural|key)?.decisions?"
    "work.breakdown"
    "open.questions"
)

optional_sections=(
    "milestones?"
    "dependenc(y|ies)"
    "tooling"
    "(delivery|branch).strategy"
    "(data|file).*(workflow|flow)"
)

# Extract all headings from the markdown file
headings=$(grep -iE '^#{1,3}\s' "$plan_file" | sed 's/^#*\s*//' | tr '[:upper:]' '[:lower:]')

missing=()
found=0
total=${#required_sections[@]}

for pattern in "${required_sections[@]}"; do
    if echo "$headings" | grep -qiE "$pattern"; then
        found=$((found + 1))
    else
        missing+=("$pattern")
    fi
done

# Optional sections (only in strict mode)
optional_missing=()
if [ "$strict" = "--strict" ]; then
    for pattern in "${optional_sections[@]}"; do
        if ! echo "$headings" | grep -qiE "$pattern"; then
            optional_missing+=("$pattern")
        fi
    done
fi

# Report
if [ ${#missing[@]} -eq 0 ]; then
    echo "PASS: All $total required sections found in $plan_file"
    if [ "$strict" = "--strict" ] && [ ${#optional_missing[@]} -gt 0 ]; then
        echo "INFO: Missing optional sections:" >&2
        for m in "${optional_missing[@]}"; do
            echo "  - $m" >&2
        done
    fi
    exit 0
else
    echo "FAIL: $found/$total required sections found in $plan_file" >&2
    echo "Missing sections:" >&2
    for m in "${missing[@]}"; do
        echo "  - $m" >&2
    done
    if [ "$strict" = "--strict" ] && [ ${#optional_missing[@]} -gt 0 ]; then
        echo "Missing optional sections:" >&2
        for m in "${optional_missing[@]}"; do
            echo "  - $m" >&2
        done
    fi
    exit 1
fi
