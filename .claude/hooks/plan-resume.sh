#!/usr/bin/env bash
# plan-resume.sh - SessionStart hook to inject living plan into context
#
# Extracts key sections from .claude/plan.md. Keeps context small.
# (#5) Auto-creates a minimal plan if none exists (non-gwt sessions).
# Silent exit when plan has no meaningful content.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

PLAN_FILE="$PROJECT_DIR/.claude/plan.md"

# (#5) Auto-create minimal plan for interactive (non-gwt) sessions
if [[ ! -f "$PLAN_FILE" ]]; then
    # Only create if .claude/ dir exists (indicates a Claude project)
    if [[ -d "$PROJECT_DIR/.claude" ]]; then
        BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        cat >"$PLAN_FILE" <<TEMPLATE
---
branch: "$BRANCH"
created: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
last_updated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

# Session Plan

## Objective

_Describe what you're working on._

## Failed Approaches

_Record approaches that didn't work and WHY. This prevents retrying dead ends after compaction._

## Success Criteria

_Define quantifiable objectives. What does 'done' look like?_

## Known Limitations

_Track constraints and blockers discovered during work._

## Current State

_Update this section as work progresses. This survives context compaction._

## Next Steps

_What needs to happen next._

## Useful Commands

_Save commands here that produced valuable results or solved problems._
TEMPLATE
        echo "Created .claude/plan.md — update it as you work to persist state across compactions."
    fi
    exit 0
fi

EXTRACTOR="$PROJECT_DIR/.claude/hooks/plan-extract-sections.sh"
if [[ ! -x "$EXTRACTOR" ]]; then
    EXTRACTOR="$HOME/dotfiles/.claude/hooks/plan-extract-sections.sh"
fi

SECTIONS=""
if [[ -x "$EXTRACTOR" ]]; then
    SECTIONS=$(bash "$EXTRACTOR" "$PLAN_FILE" 2>/dev/null) || true
fi

if [[ -n "$SECTIONS" ]]; then
    echo "=== Living Plan (.claude/plan.md) ==="
    echo "$SECTIONS"
    echo "=== End Living Plan ==="
    echo ""
    echo "Read .claude/plan.md for full context. Keep it updated as you work."
fi

exit 0
