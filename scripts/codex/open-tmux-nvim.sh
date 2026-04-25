#!/usr/bin/env bash

set -euo pipefail

TMUX_BIN="${TMUX_BIN:-$(command -v tmux || true)}"
TARGET_FILE="${1:-}"

if [[ -z "$TARGET_FILE" ]]; then
	echo "Usage: $(basename "$0") <file>" >&2
	exit 1
fi

if [[ ! -e "$TARGET_FILE" ]]; then
	echo "File does not exist: $TARGET_FILE" >&2
	exit 1
fi

if [[ -z "$TMUX_BIN" ]] || [[ ! -x "$TMUX_BIN" ]]; then
	echo "tmux is not available in PATH" >&2
	exit 1
fi

TARGET_DIR="$(cd "$(dirname "$TARGET_FILE")" && pwd)"
TARGET_FILE_ABS="$(cd "$TARGET_DIR" && printf '%s/%s' "$TARGET_DIR" "$(basename "$TARGET_FILE")")"

path_prefix_score() {
	local pane_path="$1"
	local target_path="$2"
	local score=0

	while [[ -n "$pane_path" ]]; do
		if [[ "$target_path" == "$pane_path" ]] || [[ "$target_path" == "$pane_path"/* ]]; then
			score=${#pane_path}
			break
		fi

		if [[ "$pane_path" == "/" ]]; then
			break
		fi

		pane_path="${pane_path%/*}"
		if [[ -z "$pane_path" ]]; then
			pane_path="/"
		fi
	done

	printf '%s\n' "$score"
}

scope_rank() {
	case "$1" in
	same-window)
		printf '2\n'
		;;
	same-session)
		printf '1\n'
		;;
	*)
		printf '0\n'
		;;
	esac
}

pane_has_nvim() {
	local pane_tty="$1"
	# macOS tmux panes often show fish as pane_current_command even when nvim is
	# running deeper in the tty process tree, so inspect the full tty process list.
	# shellcheck disable=SC2009
	ps -o args= -t "$pane_tty" 2>/dev/null | grep -qE '(^|/)(nvim)( |$)'
}

latest_client_target="$($TMUX_BIN list-clients -F '#{client_activity} #{session_name}:#{window_index}.#{pane_index}' 2>/dev/null | sort -nr | awk 'NR == 1 { print $2 }')"

if [[ -z "$latest_client_target" ]]; then
	echo "No active tmux client found" >&2
	exit 1
fi

active_window_target="$($TMUX_BIN display-message -p -t "$latest_client_target" '#{session_name}:#{window_index}')"
active_pane_info="$($TMUX_BIN display-message -p -t "$latest_client_target" '#{pane_id}')"

read -r active_pane_id <<<"$active_pane_info"

target_pane_id=""
fallback_pane_id=""
fallback_scope=""
fallback_prefix=-1
fallback_activity=-1

while read -r pane_id pane_tty pane_window_target pane_session_name pane_path; do
	if [[ "$pane_id" == "$active_pane_id" ]]; then
		continue
	fi

	if ! pane_has_nvim "$pane_tty"; then
		continue
	fi

	prefix_score=$(path_prefix_score "$pane_path" "$TARGET_DIR")

	if [[ "$pane_window_target" == "$active_window_target" ]]; then
		candidate_scope="same-window"
	elif [[ "$pane_session_name" == "${active_window_target%%:*}" ]]; then
		candidate_scope="same-session"
	else
		candidate_scope="global"
	fi
	candidate_scope_rank=$(scope_rank "$candidate_scope")
	fallback_scope_rank=$(scope_rank "$fallback_scope")

	client_activity="$($TMUX_BIN list-clients -F '#{client_activity} #{session_name}:#{window_index}' 2>/dev/null | awk -v target="$pane_window_target" '$2 == target { print $1; found = 1 } END { if (!found) print -1 }')"

	if [[ -z "$fallback_pane_id" ]] ||
		((candidate_scope_rank > fallback_scope_rank)) ||
		((candidate_scope_rank == fallback_scope_rank && prefix_score > fallback_prefix)) ||
		((candidate_scope_rank == fallback_scope_rank && prefix_score == fallback_prefix && client_activity > fallback_activity)); then
		fallback_pane_id=$pane_id
		fallback_scope=$candidate_scope
		fallback_prefix=$prefix_score
		fallback_activity=$client_activity
	fi
done < <("$TMUX_BIN" list-panes -a -F '#{pane_id} #{pane_tty} #{session_name}:#{window_index} #{session_name} #{pane_current_path}')

if [[ -z "$target_pane_id" ]]; then
	if [[ -z "$fallback_pane_id" ]]; then
		echo "No tmux pane running nvim was found" >&2
		exit 1
	fi

	target_pane_id=$fallback_pane_id
fi

vim_command=":lua vim.cmd.cd(vim.fn.fnameescape([[${TARGET_DIR}]])); vim.cmd.edit(vim.fn.fnameescape([[${TARGET_FILE_ABS}]]))"

"$TMUX_BIN" send-keys -t "$target_pane_id" Escape
"$TMUX_BIN" send-keys -t "$target_pane_id" -l "$vim_command"
"$TMUX_BIN" send-keys -t "$target_pane_id" Enter
