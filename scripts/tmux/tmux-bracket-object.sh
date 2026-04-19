#!/usr/bin/env bash
# tmux-bracket-object.sh - Select around/inside bracket pairs in tmux copy mode
# Usage: tmux-bracket-object.sh [around|inside] [paren|brace|square|angle|any]
#
# Finds the innermost enclosing bracket pair on the current line,
# even when the cursor is NOT on a bracket character (Vim-like behavior).
# Uses stack-based scanning for correct nesting. Single bash fork per invocation.
#
# Types:  paren = (), brace = {}, square = [], angle = <>, any = all

set -uo pipefail

mode="${1:-inside}"
bracket_type="${2:-any}"

cursor_x=$(tmux display -p '#{copy_cursor_x}')
cursor_y=$(tmux display -p '#{copy_cursor_y}')
scroll_pos=$(tmux display -p '#{scroll_position}')

[[ -z "$cursor_x" ]] && exit 0

capture_line=$((cursor_y - scroll_pos))
line=$(tmux capture-pane -p -S "$capture_line" -E "$capture_line") || exit 0
len=${#line}

case "$bracket_type" in
paren) pairs=('()') ;;
brace) pairs=('{}') ;;
square) pairs=('[]') ;;
angle) pairs=('<>') ;;
any) pairs=('()' '{}' '[]') ;;
*) exit 0 ;;
esac

best_start=-1
best_end=-1
best_width=999999

for pair in "${pairs[@]}"; do
    open="${pair:0:1}"
    close="${pair:1:1}"

    # Left scan: find nearest unmatched opening bracket at or before cursor
    # If cursor is on a closing bracket of this type, skip it
    depth=0
    start=-1
    left_from=$cursor_x
    [[ "${line:$cursor_x:1}" == "$close" ]] && left_from=$((cursor_x - 1))

    for ((i = left_from; i >= 0; i--)); do
        ch="${line:$i:1}"
        if [[ "$ch" == "$close" ]]; then
            ((depth++)) || true
        elif [[ "$ch" == "$open" ]]; then
            if ((depth > 0)); then
                ((depth--))
            else
                start=$i
                break
            fi
        fi
    done

    [[ $start -eq -1 ]] && continue

    # Right scan: find matching closing bracket from start+1
    depth=0
    end=-1
    for ((i = start + 1; i < len; i++)); do
        ch="${line:$i:1}"
        if [[ "$ch" == "$open" ]]; then
            ((depth++)) || true
        elif [[ "$ch" == "$close" ]]; then
            if ((depth > 0)); then
                ((depth--))
            else
                end=$i
                break
            fi
        fi
    done

    [[ $end -eq -1 ]] && continue

    width=$((end - start))
    if ((width < best_width)); then
        best_start=$start
        best_end=$end
        best_width=$width
    fi
done

[[ $best_start -eq -1 ]] && exit 0

if [[ "$mode" == "inside" ]]; then
    best_start=$((best_start + 1))
    best_end=$((best_end - 1))
    [[ $best_start -gt $best_end ]] && exit 0
fi

tmux send-keys -X start-of-line
[[ $best_start -gt 0 ]] && tmux send-keys -X -N "$best_start" cursor-right
tmux send-keys -X begin-selection
move=$((best_end - best_start))
[[ $move -gt 0 ]] && tmux send-keys -X -N "$move" cursor-right
exit 0
