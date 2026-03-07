#!/usr/bin/env bash
# tmux-quote-object.sh - Select around/inside quotes in tmux copy mode
# Usage: tmux-quote-object.sh [around|inside] [any|double|single|backtick]
#
# Finds the enclosing quote pair on the current line and moves the
# copy-mode cursor to select it. Called from tmux key table bindings.
# Single bash fork per invocation — acceptable for a deliberate keypress.

set -uo pipefail

mode="${1:-around}"    # "around" or "inside"
quote_type="${2:-any}" # "any", "double", "single", "backtick"

# Read cursor position and line content from copy mode
cursor_x=$(tmux display -p '#{copy_cursor_x}')
cursor_line=$(tmux display -p '#{copy_cursor_line}')
history_size=$(tmux display -p '#{history_size}')

# Bail if not in copy mode (format vars return empty)
[[ -z "$cursor_x" ]] && exit 0

# Convert absolute line number to capture-pane coordinate
# capture-pane: 0 = first visible line, negative = history
capture_line=$((cursor_line - history_size))
line=$(tmux capture-pane -p -S "$capture_line" -E "$capture_line") || exit 0

# Which quote characters to search for
case "$quote_type" in
double) chars=('"') ;;
single) chars=("'") ;;
backtick) chars=('`') ;;
any) chars=('"' "'" '`') ;;
*) exit 0 ;;
esac

# Find the innermost enclosing quote pair containing the cursor
best_start=-1
best_end=-1
best_width=999999

for q in "${chars[@]}"; do
    # Collect all positions of this quote character
    positions=()
    for ((i = 0; i < ${#line}; i++)); do
        [[ "${line:$i:1}" == "$q" ]] && positions+=("$i")
    done

    # Pair consecutive quotes and check if cursor is inside
    local_len=${#positions[@]}
    p=0
    while ((p + 1 < local_len)); do
        start=${positions[$p]}
        end=${positions[$((p + 1))]}
        if ((start <= cursor_x && cursor_x <= end)); then
            width=$((end - start))
            if ((width < best_width)); then
                best_start=$start
                best_end=$end
                best_width=$width
            fi
        fi
        ((p += 2)) || true
    done
done

# No enclosing quotes found
[[ $best_start -eq -1 ]] && exit 0

# Adjust for inside mode (exclude the quote characters)
if [[ "$mode" == "inside" ]]; then
    best_start=$((best_start + 1))
    best_end=$((best_end - 1))
    # Empty string between adjacent quotes — nothing to select
    [[ $best_start -gt $best_end ]] && exit 0
fi

# Move cursor to start position and select to end position
tmux send-keys -X start-of-line
[[ $best_start -gt 0 ]] && tmux send-keys -X -N "$best_start" cursor-right
tmux send-keys -X begin-selection
move=$((best_end - best_start))
[[ $move -gt 0 ]] && tmux send-keys -X -N "$move" cursor-right
