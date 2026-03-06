#!/usr/bin/env bash
# Claude Code statusline — Tokyo Night themed
# Reads JSON from stdin, outputs ANSI-colored status bar
set -euo pipefail

INPUT=$(cat)

# Parse fields with jq, fallback gracefully
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')
DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // "?"')
FOLDER=$(basename "$DIR")
COST_RAW=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0')
DURATION_MS=$(echo "$INPUT" | jq -r '.cost.total_duration_ms // 0')
AGENT=$(echo "$INPUT" | jq -r '.agent.name // empty')
WORKTREE=$(echo "$INPUT" | jq -r '.worktree // empty')
LINES_ADDED=$(echo "$INPUT" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$INPUT" | jq -r '.cost.total_lines_removed // 0')

# Format cost to 2 decimal places
COST=$(printf "%.0f" "$COST_RAW")

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

# --- Subscription usage (cached 60s, background refresh) ---
USAGE_CACHE="/tmp/claude-statusline-usage"
USAGE_SCRIPT="$HOME/dotfiles/scripts/ticket-queue/claude-usage.sh"
USAGE_TTL=60
USAGE_PCT=""

if [ -f "$USAGE_CACHE" ]; then
    USAGE_CACHE_AGE=$((NOW - $(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0)))
    USAGE_PCT=$(cat "$USAGE_CACHE" 2>/dev/null || echo "")

    # Background refresh if stale
    if [ "$USAGE_CACHE_AGE" -gt "$USAGE_TTL" ] && [ -x "$USAGE_SCRIPT" ]; then
        (
            json=$("$USAGE_SCRIPT" --json 2>/dev/null) || exit 0
            pct=$(echo "$json" | jq -r '.five_hour.utilization // empty' 2>/dev/null) || exit 0
            [ -n "$pct" ] && printf '%.0f' "$pct" >"$USAGE_CACHE"
        ) &
        disown 2>/dev/null
    fi
elif [ -x "$USAGE_SCRIPT" ]; then
    # First call: seed cache in background
    (
        json=$("$USAGE_SCRIPT" --json 2>/dev/null) || exit 0
        pct=$(echo "$json" | jq -r '.five_hour.utilization // empty' 2>/dev/null) || exit 0
        [ -n "$pct" ] && printf '%.0f' "$pct" >"$USAGE_CACHE"
    ) &
    disown 2>/dev/null
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

# Usage color based on percentage
USAGE_COLOR="$DIM"
if [ -n "$USAGE_PCT" ]; then
    if [ "$USAGE_PCT" -lt 50 ] 2>/dev/null; then
        USAGE_COLOR="$GREEN"
    elif [ "$USAGE_PCT" -lt 75 ] 2>/dev/null; then
        USAGE_COLOR="$YELLOW"
    elif [ "$USAGE_PCT" -lt 90 ] 2>/dev/null; then
        USAGE_COLOR="$RED"
    else
        USAGE_COLOR="$RED"
    fi
fi

# Build status line
STATUS=""
STATUS+="${BLUE}${MODEL}${RESET}"
STATUS+=" ${DIM}|${RESET} "
STATUS+="${PURPLE}${FOLDER}${RESET}"

if [ -n "$BRANCH" ]; then
    STATUS+="${DIM}:${RESET}${GREEN}${BRANCH}${RESET}"
fi

if [ -n "$WORKTREE" ]; then
    WORKTREE_NAME=$(basename "$WORKTREE")
    STATUS+="${DIM}/${RESET}${YELLOW}${WORKTREE_NAME}${RESET}"
fi

if [ -n "$AGENT" ]; then
    STATUS+=" ${DIM}|${RESET} ${YELLOW}@${AGENT}${RESET}"
fi

STATUS+=" ${DIM}|${RESET} "
STATUS+="${PCT_COLOR}ctx:${PCT_INT}%${RESET}"

if [ -n "$USAGE_PCT" ]; then
    STATUS+=" ${DIM}|${RESET} "
    STATUS+="${USAGE_COLOR}5h:${USAGE_PCT}%${RESET}"
fi

STATUS+=" ${DIM}|${RESET} "
STATUS+="${DIM}\$${COST}${RESET}"

if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
    STATUS+=" ${DIM}|${RESET} "
    STATUS+="${GREEN}+${LINES_ADDED}${RESET}${DIM}/${RESET}${RED}-${LINES_REMOVED}${RESET}"
fi

STATUS+=" ${DIM}|${RESET} "
STATUS+="${DIM}${DURATION}${RESET}"

printf '%b' "$STATUS"
