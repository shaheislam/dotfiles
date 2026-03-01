#!/usr/bin/env bash
# Claude Code statusline — Tokyo Night themed
# Reads JSON from stdin, outputs ANSI-colored status bar
set -euo pipefail

INPUT=$(cat)

# Parse fields with jq, fallback gracefully
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')
DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // "?"')
FOLDER=$(basename "$DIR")
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0')
DURATION_MS=$(echo "$INPUT" | jq -r '.cost.total_duration_ms // 0')
AGENT=$(echo "$INPUT" | jq -r '.agent.name // empty')

# Duration: ms → human readable
DURATION_S=$((DURATION_MS / 1000))
if [ "$DURATION_S" -lt 60 ]; then
    DURATION="${DURATION_S}s"
elif [ "$DURATION_S" -lt 3600 ]; then
    DURATION="$((DURATION_S / 60))m$((DURATION_S % 60))s"
else
    DURATION="$((DURATION_S / 3600))h$((DURATION_S % 3600 / 60))m"
fi

# Git branch (cached 5s)
CACHE="/tmp/claude-statusline-cache"
NOW=$(date +%s)
if [ -f "$CACHE" ]; then
    CACHE_AGE=$((NOW - $(stat -f %m "$CACHE" 2>/dev/null || echo 0)))
else
    CACHE_AGE=999
fi

if [ "$CACHE_AGE" -gt 5 ]; then
    BRANCH=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    echo "$BRANCH" >"$CACHE"
else
    BRANCH=$(cat "$CACHE")
fi

# Tokyo Night ANSI colors
BLUE='\033[38;2;122;162;247m'   # #7aa2f7
GREEN='\033[38;2;158;206;106m'  # #9ece6a
YELLOW='\033[38;2;224;175;104m' # #e0af68
RED='\033[38;2;247;118;142m'    # #f7768e
PURPLE='\033[38;2;187;154;247m' # #bb9af7
DIM='\033[38;2;86;95;137m'      # #565f89
RESET='\033[0m'

# Context color based on percentage
PCT_INT=${PCT%.*}
if [ "$PCT_INT" -lt 50 ]; then
    PCT_COLOR="$GREEN"
elif [ "$PCT_INT" -lt 80 ]; then
    PCT_COLOR="$YELLOW"
else
    PCT_COLOR="$RED"
fi

# Build status line
STATUS=""
STATUS+="${BLUE}${MODEL}${RESET}"
STATUS+=" ${DIM}|${RESET} "
STATUS+="${PURPLE}${FOLDER}${RESET}"

if [ -n "$BRANCH" ]; then
    STATUS+="${DIM}:${RESET}${GREEN}${BRANCH}${RESET}"
fi

if [ -n "$AGENT" ]; then
    STATUS+=" ${DIM}|${RESET} ${YELLOW}@${AGENT}${RESET}"
fi

STATUS+=" ${DIM}|${RESET} "
STATUS+="${PCT_COLOR}ctx:${PCT_INT}%${RESET}"
STATUS+=" ${DIM}|${RESET} "
STATUS+="${DIM}\$${COST}${RESET}"
STATUS+=" ${DIM}|${RESET} "
STATUS+="${DIM}${DURATION}${RESET}"

printf '%b' "$STATUS"
