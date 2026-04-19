#!/usr/bin/env bash
# tmux-url-object.sh - Select URL under cursor in tmux copy mode
# Usage: tmux-url-object.sh [around|inside]
#
# Detects URLs (http://, https://, or domain.tld patterns) and selects them.
# Strips trailing punctuation that's likely not part of the URL.
# iu: just the URL, au: URL + one trailing space

set -uo pipefail

mode="${1:-inside}"

cursor_x=$(tmux display -p '#{copy_cursor_x}')
cursor_y=$(tmux display -p '#{copy_cursor_y}')
scroll_pos=$(tmux display -p '#{scroll_position}')
[[ -z "$cursor_x" ]] && exit 0

capture_line=$((cursor_y - scroll_pos))
line=$(tmux capture-pane -p -S "$capture_line" -E "$capture_line") || exit 0
len=${#line}

# URL-safe characters (RFC 3986 + common extras)
is_url_char() {
    [[ "$1" =~ [A-Za-z0-9_.~:/?#@\!\$\&\'\(\)\*\+,\;=%\-] ]]
}

ch="${line:$cursor_x:1}"
is_url_char "$ch" || exit 0

# Scan left for URL boundary
start=$cursor_x
while ((start > 0)); do
    prev="${line:$((start - 1)):1}"
    is_url_char "$prev" || break
    ((start--))
done

# Scan right for URL boundary
end=$cursor_x
while ((end + 1 < len)); do
    next="${line:$((end + 1)):1}"
    is_url_char "$next" || break
    ((end++)) || true
done

candidate="${line:$start:$((end - start + 1))}"

# Must look like a URL: has :// or domain.tld pattern
if [[ ! "$candidate" =~ :// ]] && [[ ! "$candidate" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,} ]]; then
    exit 0
fi

# Strip trailing punctuation unlikely to be part of URL
while ((end > start)) && [[ "${line:$end:1}" =~ [\.\,\;\:\!\?\)\]\}] ]]; do
    ((end--))
done

# Balance parentheses: if URL has unmatched ), strip trailing )
candidate="${line:$start:$((end - start + 1))}"
opens=0
closes=0
for ((i = 0; i < ${#candidate}; i++)); do
    case "${candidate:$i:1}" in
    '(') ((opens++)) || true ;;
    ')') ((closes++)) || true ;;
    esac
done
while ((closes > opens && end > start)) && [[ "${line:$end:1}" == ")" ]]; do
    ((end--))
    ((closes--))
done

if [[ "$mode" == "around" ]] && ((end + 1 < len)); then
    [[ "${line:$((end + 1)):1}" == " " ]] && ((end++)) || true
fi

tmux send-keys -X start-of-line
[[ $start -gt 0 ]] && tmux send-keys -X -N "$start" cursor-right
tmux send-keys -X begin-selection
move=$((end - start))
[[ $move -gt 0 ]] && tmux send-keys -X -N "$move" cursor-right
exit 0
