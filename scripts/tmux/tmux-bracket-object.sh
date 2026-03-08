#!/usr/bin/env bash
# tmux-bracket-object.sh - Select around/inside bracket pairs in tmux copy mode
# Usage: tmux-bracket-object.sh [around|inside] [paren|brace|any]
#
# Finds the innermost enclosing bracket pair on the current line,
# even when the cursor is NOT on a bracket character (Vim-like behavior).
# Uses stack-based scanning for correct nesting. Single bash fork per invocation.
#
# Types:  paren = () only (Vim 'b'), brace = {} only (Vim 'B'), any = all

set -uo pipefail

dbg=/tmp/bracket-debug.log
mode="${1:-inside}"
bracket_type="${2:-any}"

cursor_x=$(tmux display -p '#{copy_cursor_x}')
cursor_y=$(tmux display -p '#{copy_cursor_y}')
scroll_pos=$(tmux display -p '#{scroll_position}')

echo "mode=$mode type=$bracket_type cx=$cursor_x cy=$cursor_y sp=$scroll_pos" >"$dbg"

[[ -z "$cursor_x" ]] && {
    echo "BAIL: empty cursor_x" >>"$dbg"
    exit 0
}

capture_line=$((cursor_y - scroll_pos))
line=$(tmux capture-pane -p -S "$capture_line" -E "$capture_line") || exit 0
len=${#line}
echo "capture_line=$capture_line len=$len line=[$line]" >>"$dbg"

case "$bracket_type" in
paren) pairs=('()') ;;
brace) pairs=('{}') ;;
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
            ((depth++))
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
            ((depth++))
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

echo "best_start=$best_start best_end=$best_end" >>"$dbg"
[[ $best_start -eq -1 ]] && {
    echo "BAIL: no brackets" >>"$dbg"
    exit 0
}

if [[ "$mode" == "inside" ]]; then
    best_start=$((best_start + 1))
    best_end=$((best_end - 1))
    [[ $best_start -gt $best_end ]] && exit 0
fi

tmux send-keys -X start-of-line
[[ $best_start -gt 0 ]] && tmux send-keys -X -N "$best_start" cursor-right
tmux send-keys -X begin-selection
move=$((best_end - best_start))
echo "selecting: start=$best_start end=$best_end move=$move" >>"$dbg"
[[ $move -gt 0 ]] && tmux send-keys -X -N "$move" cursor-right
exit 0
