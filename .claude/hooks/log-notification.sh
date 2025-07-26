#!/bin/bash
# Notification Logging Hook
# Logs Claude Code notifications for monitoring

# Create logs directory if it doesn't exist
LOG_DIR="$HOME/.claude/hooks/logs"
mkdir -p "$LOG_DIR"

# Log file with date
LOG_FILE="$LOG_DIR/notifications-$(date +%Y-%m-%d).log"

# Read JSON input from stdin
INPUT=$(cat)

# Get current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Parse notification type and message using Python
NOTIFICATION_TYPE=$(echo "$INPUT" | python3 -c "import json, sys; print(json.load(sys.stdin).get('notification_type', 'unknown'))" 2>/dev/null || echo "parse_error")
MESSAGE=$(echo "$INPUT" | python3 -c "import json, sys; print(json.load(sys.stdin).get('message', '')[:100])" 2>/dev/null || echo "parse_error")

# Log to file
echo "[$TIMESTAMP] Type: $NOTIFICATION_TYPE | Message: $MESSAGE" >> "$LOG_FILE"

# Also output to stdout for immediate visibility
echo "🔔 [Notification Hook] $NOTIFICATION_TYPE - $MESSAGE"

# Always exit 0 to not interfere
exit 0