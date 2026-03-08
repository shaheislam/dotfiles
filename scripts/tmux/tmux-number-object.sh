#!/usr/bin/env bash
# tmux-number-object.sh - Select number under cursor in tmux copy mode
# Usage: tmux-number-object.sh [around|inside]
#
# Finds a numeric sequence (digits, optional decimal, optional leading minus)
# at the cursor position. Useful for PIDs, ports, line numbers, etc.
# in: just the number, an: number + one trailing space

set -uo pipefail

mode="${1:-inside}"

cursor_x=$(tmux display -p '#{copy_cursor_x}')
cursor_y=$(tmux display -p '#{copy_cursor_y}')
scroll_pos=$(tmux display -p '#{scroll_position}')
[[ -z "$cursor_x" ]] && exit 0

capture_line=$((cursor_y - scroll_pos))
line=$(tmux capture-pane -p -S "$capture_line" -E "$capture_line") || exit 0
len=${#line}

ch="${line:$cursor_x:1}"
[[ "$ch" =~ [0-9] ]] || exit 0

# Scan left for start of number
start=$cursor_x
while ((start > 0)) && [[ "${line:$((start - 1)):1}" =~ [0-9.] ]]; do
    ((start--))
done
# Include leading minus if present and preceded by non-digit
if ((start > 0)) && [[ "${line:$((start - 1)):1}" == "-" ]]; then
    prev2=$((start - 2))
    if ((prev2 < 0)) || [[ ! "${line:$prev2:1}" =~ [0-9] ]]; then
        ((start--))
    fi
fi

# Scan right for end of number
end=$cursor_x
while ((end + 1 < len)) && [[ "${line:$((end + 1)):1}" =~ [0-9.] ]]; do
    ((end++))
done

# Strip trailing dots (likely sentence punctuation, not decimal)
while ((end > start)) && [[ "${line:$end:1}" == "." ]]; do
    ((end--))
done

# For around mode, include one trailing space
if [[ "$mode" == "around" ]] && ((end + 1 < len)); then
    [[ "${line:$((end + 1)):1}" == " " ]] && ((end++))
fi

tmux send-keys -X start-of-line
[[ $start -gt 0 ]] && tmux send-keys -X -N "$start" cursor-right
tmux send-keys -X begin-selection
move=$((end - start))
[[ $move -gt 0 ]] && tmux send-keys -X -N "$move" cursor-right
exit 0
