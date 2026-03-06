#!/bin/bash
set -euo pipefail
# ConfigChange hook - log configuration changes for audit trail

INPUT=$(cat)
SOURCE=$(echo "$INPUT" | python3 -c "import json, sys; print(json.load(sys.stdin).get('source', 'unknown'))" 2>/dev/null || echo "unknown")

LOG_DIR="$HOME/.claude/hooks/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/config-changes-$(date +%Y-%m-%d).log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ConfigChange: source=$SOURCE" >>"$LOG_FILE"

exit 0
