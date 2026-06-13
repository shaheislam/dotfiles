#!/usr/bin/env bash
#
# nvim-open-file.sh - Open a file in the Neovim pane of the launching tmux window
#
# Usage: nvim-open-file.sh <file-path> [--line LINE] [--target TMUX-TARGET]
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
line_number=""
target=""
source_pane="${TMUX_PANE:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
    --line)
        line_number="$2"
        shift 2
        ;;
    --target)
        target="$2"
        source_pane="$2"
        shift 2
        ;;
    -*)
        echo "Error: unknown option $1" >&2
        echo "Usage: nvim-open-file.sh <file-path> [--line LINE] [--target TMUX-TARGET]" >&2
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

if [[ -n "$line_number" && ! "$line_number" =~ ^[0-9]+$ ]]; then
    echo "Error: --line must be a positive integer" >&2
    exit 1
fi

# Not in tmux — try to recover context from OpenCode attach files.
# OpenCode's launchd server inherits neither $TMUX nor $TMUX_PANE, but
# tmux-open.sh writes a pane= entry to an attach file we can read directly.
if [[ -z "${TMUX:-}" ]]; then
    _attach_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/attaches"
    _recovered_pane=""
    if tmux info >/dev/null 2>&1 && [[ -d "$_attach_dir" ]]; then
        _recovered_pane=$(
            find "$_attach_dir" -maxdepth 1 -name '*.pid' \
                -exec grep -h '^pane=' {} + 2>/dev/null |
                head -1 | cut -d= -f2
        )
    fi
    if [[ -z "$_recovered_pane" ]]; then
        echo "Not in tmux, skipping nvim open" >&2
        exit 0
    fi
    source_pane="$_recovered_pane"
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
    if [[ -n "$line_number" ]]; then
        tmux send-keys -t "${target}.${nvim_pane}" \
            ":lua vim.cmd('edit ' .. [[${file_path}]]); vim.api.nvim_win_set_cursor(0, {${line_number}, 0}); vim.cmd('normal! zz'); vim.cmd('checktime')" Enter
    else
        tmux send-keys -t "${target}.${nvim_pane}" \
            ":lua vim.cmd('edit ' .. [[${file_path}]]); vim.cmd('checktime')" Enter
    fi
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
    if [[ -n "$line_number" ]]; then
        tmux split-window "$orientation" -c '#{pane_current_path}' -t "$split_target" "nvim +$line_number $quoted_path"
    else
        tmux split-window "$orientation" -c '#{pane_current_path}' -t "$split_target" "nvim $quoted_path"
    fi
    echo "Opened nvim split (${orientation}) with ${file_path} (${target})"
fi
