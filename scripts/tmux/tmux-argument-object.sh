#!/usr/bin/env bash
# tmux-argument-object.sh - Select comma-separated argument in tmux copy mode
# Usage: tmux-argument-object.sh [around|inside]
#
# Finds the enclosing bracket pair, then selects the comma-delimited argument
# containing the cursor. Handles nested brackets within arguments.
# i,: argument content (trimmed), a,: argument + trailing comma/space

set -uo pipefail

mode="${1:-inside}"

cursor_x=$(tmux display -p '#{copy_cursor_x}')
cursor_y=$(tmux display -p '#{copy_cursor_y}')
scroll_pos=$(tmux display -p '#{scroll_position}')
[[ -z "$cursor_x" ]] && exit 0

capture_line=$((cursor_y - scroll_pos))
line=$(tmux capture-pane -p -S "$capture_line" -E "$capture_line") || exit 0
len=${#line}

# --- Find innermost enclosing brackets ---
pairs=('()' '{}' '[]')
bk_start=-1
bk_end=-1
bk_width=999999

for pair in "${pairs[@]}"; do
    open="${pair:0:1}"
    close="${pair:1:1}"

    depth=0
    s=-1
    lf=$cursor_x
    [[ "${line:$cursor_x:1}" == "$close" ]] && lf=$((cursor_x - 1))

    for ((i = lf; i >= 0; i--)); do
        ch="${line:$i:1}"
        if [[ "$ch" == "$close" ]]; then
            ((depth++))
        elif [[ "$ch" == "$open" ]]; then
            if ((depth > 0)); then
                ((depth--))
            else
                s=$i
                break
            fi
        fi
    done
    [[ $s -eq -1 ]] && continue

    depth=0
    e=-1
    for ((i = s + 1; i < len; i++)); do
        ch="${line:$i:1}"
        if [[ "$ch" == "$open" ]]; then
            ((depth++))
        elif [[ "$ch" == "$close" ]]; then
            if ((depth > 0)); then
                ((depth--))
            else
                e=$i
                break
            fi
        fi
    done
    [[ $e -eq -1 ]] && continue

    w=$((e - s))
    if ((w < bk_width)); then
        bk_start=$s
        bk_end=$e
        bk_width=$w
    fi
done

[[ $bk_start -eq -1 ]] && exit 0

# --- Find argument boundaries within brackets ---
content_start=$((bk_start + 1))
content_end=$((bk_end - 1))
((content_start > content_end)) && exit 0

# Scan for comma before cursor (respecting nested brackets)
arg_start=$content_start
depth=0
for ((i = content_start; i < cursor_x && i <= content_end; i++)); do
    ch="${line:$i:1}"
    case "$ch" in
    '(' | '[' | '{') ((depth++)) ;;
    ')' | ']' | '}') ((depth > 0)) && ((depth--)) ;;
    ',') ((depth == 0)) && arg_start=$((i + 1)) ;;
    esac
done

# Scan for comma after cursor
arg_end=$content_end
depth=0
for ((i = cursor_x; i <= content_end; i++)); do
    ch="${line:$i:1}"
    case "$ch" in
    '(' | '[' | '{') ((depth++)) ;;
    ')' | ']' | '}') ((depth > 0)) && ((depth--)) ;;
    ',')
        if ((depth == 0)); then
            arg_end=$((i - 1))
            break
        fi
        ;;
    esac
done

if [[ "$mode" == "inside" ]]; then
    # Trim whitespace
    while ((arg_start <= arg_end)) && [[ "${line:$arg_start:1}" == " " ]]; do
        ((arg_start++))
    done
    while ((arg_end >= arg_start)) && [[ "${line:$arg_end:1}" == " " ]]; do
        ((arg_end--))
    done
else
    # Around: include trailing comma+space, or leading if last arg
    next=$((arg_end + 1))
    if ((next <= content_end)) && [[ "${line:$next:1}" == "," ]]; then
        arg_end=$next
        ((arg_end + 1 <= content_end)) && [[ "${line:$((arg_end + 1)):1}" == " " ]] && ((arg_end++))
    else
        prev=$((arg_start - 1))
        if ((prev >= content_start)) && [[ "${line:$prev:1}" == " " ]]; then
            arg_start=$prev
            ((arg_start - 1 >= content_start)) && [[ "${line:$((arg_start - 1)):1}" == "," ]] && ((arg_start--))
        elif ((prev >= content_start)) && [[ "${line:$prev:1}" == "," ]]; then
            arg_start=$prev
        fi
    fi
fi

((arg_start > arg_end)) && exit 0

tmux send-keys -X start-of-line
[[ $arg_start -gt 0 ]] && tmux send-keys -X -N "$arg_start" cursor-right
tmux send-keys -X begin-selection
move=$((arg_end - arg_start))
[[ $move -gt 0 ]] && tmux send-keys -X -N "$move" cursor-right
exit 0
