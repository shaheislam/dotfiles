#!/usr/bin/env bash
#
# nvim-open-file.sh - Open a file in the Neovim pane of the current tmux window
#
# Usage: nvim-open-file.sh <file-path> [--target SESSION:WINDOW]
#
# Searches the current window first, then falls back to any nvim pane
# in the session. Exits 0 silently if not in tmux or no nvim pane
# exists (best-effort, never blocks callers).

set -euo pipefail

file_path=""
target=""

while [[ $# -gt 0 ]]; do
    case $1 in
    --target)
        target="$2"
        shift 2
        ;;
    -*)
        echo "Error: unknown option $1" >&2
        echo "Usage: nvim-open-file.sh <file-path> [--target SESSION:WINDOW]" >&2
        exit 1
        ;;
    *)
        file_path="$1"
        shift
        ;;
    esac
done

if [[ -z "$file_path" ]]; then
    echo "Error: file path required" >&2
    exit 1
fi

# Not in tmux — nothing to do
if [[ -z "${TMUX:-}" ]]; then
    echo "Not in tmux, skipping nvim open" >&2
    exit 0
fi

# Default target: current session:window
if [[ -z "$target" ]]; then
    target=$(tmux display-message -p '#{session_name}:#{window_index}')
fi

# Find nvim pane — grep returns non-zero when no match, so use || true
nvim_pane=$(tmux list-panes -t "$target" -F '#{pane_index} #{pane_current_command}' 2>/dev/null |
    grep -i nvim | head -1 | awk '{print $1}' || true)

# Fallback: search all windows in the session for an nvim pane
if [[ -z "$nvim_pane" ]]; then
    session=$(tmux display-message -p '#{session_name}')
    nvim_hit=$(tmux list-panes -s -t "$session" -F '#{window_index}:#{pane_index} #{pane_current_command}' 2>/dev/null |
        grep -i nvim | head -1 || true)
    if [[ -n "$nvim_hit" ]]; then
        win_pane="${nvim_hit%% *}"
        target="${session}:${win_pane%%:*}"
        nvim_pane="${win_pane##*:}"
    fi
fi

if [[ -z "$nvim_pane" ]]; then
    echo "No nvim pane found in session, skipping" >&2
    exit 0
fi

# Ensure normal mode, then open the file
tmux send-keys -t "${target}.${nvim_pane}" Escape Enter
sleep 0.3
# Use Lua [[ ]] long strings to avoid quoting issues with file paths
tmux send-keys -t "${target}.${nvim_pane}" \
    ":lua vim.cmd('edit ' .. [[${file_path}]]); vim.cmd('checktime')" Enter

echo "Opened ${file_path} in nvim pane ${nvim_pane} (${target})"
