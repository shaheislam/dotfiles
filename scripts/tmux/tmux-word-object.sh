#!/usr/bin/env bash
# tmux-word-object.sh - Select WORD (whitespace-delimited) in tmux copy mode
# Usage: tmux-word-object.sh [around|inside]
#
# Unlike 'w' (word), WORD includes punctuation — only whitespace is a boundary.
# Useful for selecting paths, URLs, flags, etc. in terminal output.
# iW: just the WORD, aW: WORD + trailing whitespace

set -uo pipefail

mode="${1:-inside}"

cursor_x=$(tmux display -p '#{copy_cursor_x}')
cursor_y=$(tmux display -p '#{copy_cursor_y}')
scroll_pos=$(tmux display -p '#{scroll_position}')
[[ -z "$cursor_x" ]] && exit 0

capture_line=$((cursor_y - scroll_pos))
line=$(tmux capture-pane -p -S "$capture_line" -E "$capture_line") || exit 0
len=${#line}

# Bail if cursor is on whitespace
ch="${line:$cursor_x:1}"
[[ "$ch" =~ [[:space:]] || -z "$ch" ]] && exit 0

# Scan left for WORD boundary
start=$cursor_x
while ((start > 0)) && [[ ! "${line:$((start - 1)):1}" =~ [[:space:]] ]]; do
    ((start--))
done

# Scan right for WORD boundary
end=$cursor_x
while ((end + 1 < len)) && [[ ! "${line:$((end + 1)):1}" =~ [[:space:]] ]]; do
    ((end++))
done

# For around mode, include trailing whitespace
if [[ "$mode" == "around" ]]; then
    while ((end + 1 < len)) && [[ "${line:$((end + 1)):1}" =~ [[:space:]] ]]; do
        ((end++))
    done
fi

tmux send-keys -X start-of-line
[[ $start -gt 0 ]] && tmux send-keys -X -N "$start" cursor-right
tmux send-keys -X begin-selection
move=$((end - start))
[[ $move -gt 0 ]] && tmux send-keys -X -N "$move" cursor-right
exit 0
