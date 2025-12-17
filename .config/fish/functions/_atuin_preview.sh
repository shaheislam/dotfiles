#!/bin/bash
# Preview script for Atuin FZF search
# Receives full line: {time}\t{exit}\t{duration}\t{directory}\t{exit_icon command}

INPUT="$1"

# Parse tab-separated fields
IFS=$'\t' read -r timestamp exit_code duration directory command_raw <<< "$INPUT"

# Strip ANSI codes and exit icon (first 2 chars after stripping) from command
command=$(echo "$command_raw" | sed 's/\x1b\[[0-9;]*m//g' | cut -c3-)

# Tokyo Night colors (true color ANSI)
BLUE='\033[38;2;122;162;247m'
PURPLE='\033[38;2;187;154;247m'
GREEN='\033[38;2;158;206;106m'
RED='\033[38;2;247;118;142m'
YELLOW='\033[38;2;224;175;104m'
CYAN='\033[38;2;125;207;255m'
DIM='\033[2m'
RESET='\033[0m'

# Header
echo -e "${PURPLE}╭─ Command Details ─────────────────────────────╮${RESET}"
echo ""

# Command (highlighted, cyan)
echo -e "  ${CYAN}${command}${RESET}"
echo ""

# Metadata section
echo -e "  ${DIM}Time:${RESET}      ${BLUE}${timestamp}${RESET}"

# Duration with color coding
dur_color="$RESET"
if [[ "$duration" == *"ms"* ]]; then
    dur_color="$GREEN"
elif [[ "$duration" == *"s"* ]]; then
    # Extract numeric part
    num=$(echo "$duration" | sed 's/[^0-9.]//g')
    if [[ -n "$num" ]]; then
        # Use awk for floating point comparison (bc may not be installed)
        if awk "BEGIN {exit !($num < 5)}"; then
            dur_color="$YELLOW"
        else
            dur_color="$RED"
        fi
    fi
fi
echo -e "  ${DIM}Duration:${RESET}  ${dur_color}${duration}${RESET}"

# Exit status
if [[ "$exit_code" == "0" ]]; then
    echo -e "  ${DIM}Exit:${RESET}      ${GREEN}0 (success)${RESET}"
else
    echo -e "  ${DIM}Exit:${RESET}      ${RED}${exit_code} (failed)${RESET}"
fi

# Directory
echo -e "  ${DIM}Directory:${RESET} ${directory}"

echo ""
echo -e "${PURPLE}├─ Session Context ─────────────────────────────┤${RESET}"
echo ""

# Get session context (commands around same timestamp)
if [[ -n "$timestamp" ]]; then
    # Parse the timestamp and calculate time window
    # Atuin uses format like "2025-12-17 19:03:14"
    before_time=$(date -j -v-5M -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    after_time=$(date -j -v+5M -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)

    if [[ -n "$before_time" && -n "$after_time" ]]; then
        found_current=false
        count=0
        while IFS=$'\t' read -r ctx_time ctx_cmd; do
            [[ -z "$ctx_cmd" ]] && continue
            ((count++))
            [[ $count -gt 7 ]] && break

            if [[ "$ctx_cmd" == "$command" && "$found_current" == "false" ]]; then
                echo -e "  ${GREEN}→ ${ctx_cmd}${RESET}"
                found_current=true
            elif [[ "$found_current" == "true" ]]; then
                echo -e "  ${DIM}↓ ${ctx_cmd}${RESET}"
            else
                echo -e "  ${DIM}↑ ${ctx_cmd}${RESET}"
            fi
        done < <(atuin search --format "{time}\t{command}" --after "$before_time" --before "$after_time" --limit 7 2>/dev/null)

        if [[ "$found_current" == "false" ]]; then
            echo -e "  ${DIM}(no adjacent commands found)${RESET}"
        fi
    else
        echo -e "  ${DIM}(timestamp parsing not available)${RESET}"
    fi
else
    echo -e "  ${DIM}(no timestamp available)${RESET}"
fi

echo ""
echo -e "${PURPLE}╰───────────────────────────────────────────────╯${RESET}"
