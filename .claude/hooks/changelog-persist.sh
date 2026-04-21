#!/usr/bin/env bash
# changelog-persist.sh - Emit recent changelog entries before compaction

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}" 
[[ -z "$PROJECT_DIR" ]] && exit 0

CHANGELOG_FILE="$PROJECT_DIR/.claude/CHANGELOG.md"
[[ -f "$CHANGELOG_FILE" ]] || exit 0

ENTRIES=$(grep -E '^\[.*\] (PROGRESS|DECISION|FAILED|METRIC|DISCOVERY):' "$CHANGELOG_FILE" 2>/dev/null | tail -15 || true)
[[ -n "$ENTRIES" ]] || exit 0

cat <<EOF
=== Session Changelog (last entries from .claude/CHANGELOG.md) ===
$ENTRIES
=== End Session Changelog ===
EOF
