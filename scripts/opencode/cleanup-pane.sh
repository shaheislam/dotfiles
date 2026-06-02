#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
attach_dir="$state_home/opencode/attaches"

if [ -z "$pane_id" ]; then
	exit 0
fi

pane_key() {
	local pane="$1"
	pane="${pane#%}"
	printf 'pane-%s' "$(printf '%s' "$pane" | tr -c '[:alnum:]_.-' '_')"
}

attach_file="$attach_dir/$(pane_key "$pane_id").pid"

if [ ! -f "$attach_file" ]; then
	exit 0
fi

pid=""
while IFS='=' read -r key value; do
	case "$key" in
	pid)
		pid="$value"
		;;
	esac
done <"$attach_file"

rm -f "$attach_file" >/dev/null 2>&1 || true

if [ -z "$pid" ] || ! printf '%s' "$pid" | grep -Eq '^[0-9]+$'; then
	exit 0
fi

if ! kill -0 "$pid" >/dev/null 2>&1; then
	exit 0
fi

command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
case "$command_line" in
*"opencode attach"* | *"ocv attach"* | *"scripts/bin/oc"*)
	kill "$pid" >/dev/null 2>&1 || true
	;;
esac
