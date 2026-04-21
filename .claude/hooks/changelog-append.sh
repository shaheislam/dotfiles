#!/usr/bin/env bash
# changelog-append.sh - Append a typed entry to .claude/CHANGELOG.md

set -euo pipefail

TYPE_RAW="${1:-}"
shift || true
MESSAGE="${*:-}"

if [[ -z "$TYPE_RAW" || -z "$MESSAGE" ]]; then
    echo "Usage: changelog-append.sh <progress|decision|failed|metric|discovery> \"message\"" >&2
    exit 1
fi

TYPE=$(printf '%s' "$TYPE_RAW" | tr '[:lower:]' '[:upper:]')
case "$TYPE" in
PROGRESS | DECISION | FAILED | METRIC | DISCOVERY) ;;
*)
    echo "Invalid changelog type: $TYPE_RAW" >&2
    exit 1
    ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CHANGELOG_DIR="$PROJECT_DIR/.claude"
CHANGELOG_FILE="$CHANGELOG_DIR/CHANGELOG.md"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NORMALIZED_MESSAGE=$(printf '%s' "$MESSAGE" | tr '\n\r' '  ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')

mkdir -p "$CHANGELOG_DIR"

if [[ ! -f "$CHANGELOG_FILE" ]]; then
    cat >"$CHANGELOG_FILE" <<'EOF'
# Session Changelog

Append-only per-worktree history for Claude sessions.

Format:

```text
[2026-04-21T12:34:56Z] PROGRESS: Implemented hook parity tests.
```

Allowed entry types: `PROGRESS`, `DECISION`, `FAILED`, `METRIC`, `DISCOVERY`.

Use `.claude/hooks/changelog-append.sh <type> "message"` to append structured entries.
EOF
fi

printf '[%s] %s: %s\n' "$TIMESTAMP" "$TYPE" "$NORMALIZED_MESSAGE" >>"$CHANGELOG_FILE"
printf '[%s] %s: %s\n' "$TIMESTAMP" "$TYPE" "$NORMALIZED_MESSAGE"
