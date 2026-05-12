#!/usr/bin/env bash
#
# nvim-open-file.sh - Open a file in the Neovim pane of the launching tmux window
#
# Usage: nvim-open-file.sh <file-path> [--target TMUX-TARGET]
#
# Window-local only — never reaches across to other windows. By default the
# target is derived from TMUX_PANE so background hooks do not follow the active
# tmux client/window.
# If nvim is running in the launching window, sends :edit to it.
# If not, opens a horizontal split with nvim showing the file.
# Exits 0 silently if not in tmux.
#
# Detection: matches nvim process ttys against tmux pane ttys.
# This handles nvim at any depth in the process tree (fish → fish → nvim)
# and works around macOS pgrep -t being unreliable.

set -euo pipefail

file_path=""
target=""
source_pane="${TMUX_PANE:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
    --target)
        target="$2"
        source_pane="$2"
        shift 2
        ;;
    -*)
        echo "Error: unknown option $1" >&2
        echo "Usage: nvim-open-file.sh <file-path> [--target TMUX-TARGET]" >&2
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

# Default target: window containing the pane that launched the hook. A bare
# tmux display-message can resolve to the active client/window instead.
if [[ -z "$target" ]]; then
    if [[ -n "$source_pane" ]]; then
        target=$(tmux display-message -p -t "$source_pane" '#{session_name}:#{window_index}' 2>/dev/null || true)
    fi

    if [[ -z "$target" ]]; then
        target=$(tmux display-message -p '#{session_name}:#{window_index}')
    fi
else
    normalized_target=$(tmux display-message -p -t "$target" '#{session_name}:#{window_index}' 2>/dev/null || true)
    if [[ -n "$normalized_target" ]]; then
        target="$normalized_target"
    fi
fi

split_target="$target"
if [[ -n "$source_pane" ]] && tmux display-message -p -t "$source_pane" '#{pane_id}' >/dev/null 2>&1; then
    split_target="$source_pane"
fi

# Detect nvim by matching tty: get all nvim process ttys, then check
# which pane in the current window has a matching tty.
nvim_pane=""
nvim_pids=$(pgrep nvim 2>/dev/null | tr '\n' ',' | sed 's/,$//' || true)

if [[ -n "$nvim_pids" ]]; then
    nvim_ttys=$(ps -o tty= -p "$nvim_pids" 2>/dev/null | sort -u || true)

    while IFS=: read -r idx tty; do
        tty_short="${tty##*/}"
        if echo "$nvim_ttys" | grep -q "$tty_short"; then
            nvim_pane="$idx"
            break
        fi
    done < <(tmux list-panes -t "$target" -F '#{pane_index}:#{pane_tty}' 2>/dev/null)
fi

if [[ -n "$nvim_pane" ]]; then
    # nvim already running — open file as a buffer
    tmux send-keys -t "${target}.${nvim_pane}" Escape Enter
    sleep 0.3
    tmux send-keys -t "${target}.${nvim_pane}" \
        ":lua vim.cmd('edit ' .. [[${file_path}]]); vim.cmd('checktime')" Enter
    echo "Opened ${file_path} in nvim pane ${nvim_pane} (${target})"
else
    # No nvim — open in a new pane using the same adaptive heuristic as
    # `prefix Space` in .tmux.conf: vertical split when the source pane is
    # tall, horizontal otherwise. Inherit the source pane's cwd.
    pane_width=$(tmux display-message -p -t "$split_target" '#{pane_width}' 2>/dev/null || echo 0)
    pane_height=$(tmux display-message -p -t "$split_target" '#{pane_height}' 2>/dev/null || echo 0)
    if ((pane_width > 0 && pane_height > 0 && 8 * pane_width < 20 * pane_height)); then
        orientation="-v"
    else
        orientation="-h"
    fi
    quoted_path=$(printf '%q' "$file_path")
    tmux split-window "$orientation" -c '#{pane_current_path}' -t "$split_target" "nvim $quoted_path"
    echo "Opened nvim split (${orientation}) with ${file_path} (${target})"
fi
