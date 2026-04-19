#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"
USAGE_CHECK_SCRIPT="${CLAUDE_USAGE_CHECK_SCRIPT:-$DOTFILES_ROOT/scripts/ticket-queue/claude-usage.sh}"
STATE_DIR="${CLAUDE_ROTATE_STATE_DIR:-$HOME/.claude/rotation}"
STATE_FILE="$STATE_DIR/last-profile"
if [[ -n "${CLAUDE_BIN:-}" ]]; then
	:
elif [[ -x "$HOME/.local/bin/claude" ]]; then
	CLAUDE_BIN="$HOME/.local/bin/claude"
else
	CLAUDE_BIN="$(command -v claude)"
fi

mkdir -p "$STATE_DIR"

log() {
	printf '%s\n' "$*" >&2
}

profile_label() {
	local dir="$1"
	if [[ "$dir" == "$HOME/.claude" ]]; then
		printf 'default'
	else
		basename "$dir" | sed 's/^\.claude-//'
	fi
}

profile_dirs() {
	local preferred="${CLAUDE_CONFIG_DIR:-}"
	local last_profile=""
	local dir
	local -a ordered=()
	local -a seen=()

	if [[ -f "$STATE_FILE" ]]; then
		last_profile="$(<"$STATE_FILE")"
	fi

	if [[ -n "$preferred" && -d "$preferred" ]]; then
		ordered+=("$preferred")
	fi

	if [[ -n "$last_profile" && -d "$last_profile" ]]; then
		ordered+=("$last_profile")
	fi

	if [[ -d "$HOME/.claude" ]]; then
		ordered+=("$HOME/.claude")
	fi

	shopt -s nullglob
	for dir in "$HOME"/.claude-*; do
		[[ -d "$dir" ]] || continue
		ordered+=("$dir")
	done
	shopt -u nullglob

	for dir in "${ordered[@]}"; do
		[[ -n "$dir" ]] || continue
		if [[ " ${seen[*]} " == *" $dir "* ]]; then
			continue
		fi
		seen+=("$dir")
		printf '%s\n' "$dir"
	done
}

usage_available() {
	local dir="$1"
	if [[ ! -x "$USAGE_CHECK_SCRIPT" ]]; then
		return 0
	fi

	if "$USAGE_CHECK_SCRIPT" --available --config-dir "$dir" >/dev/null 2>&1; then
		return 0
	fi

	local status=$?
	if [[ $status -eq 1 ]]; then
		return 1
	fi

	return 0
}

profile_score() {
	local dir="$1"
	local usage_json

	if [[ ! -x "$USAGE_CHECK_SCRIPT" ]]; then
		return 1
	fi

	usage_json=$("$USAGE_CHECK_SCRIPT" --json --config-dir "$dir" 2>/dev/null) || return 1

	python3 -c '
import json, sys
data = json.load(sys.stdin)
windows = [
    float((data.get("five_hour") or {}).get("utilization", 0) or 0),
    float((data.get("seven_day") or {}).get("utilization", 0) or 0),
    float((data.get("seven_day_opus") or {}).get("utilization", 0) or 0),
]
print(max(windows))
' <<<"$usage_json" 2>/dev/null
}

choose_start_profile() {
	local dir
	local best_dir=""
	local best_score=""
	local score
	while IFS= read -r dir; do
		if usage_available "$dir"; then
			score="$(profile_score "$dir" 2>/dev/null || true)"
			if [[ -n "$score" ]]; then
				if [[ -z "$best_score" ]] || python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "$score" "$best_score" 2>/dev/null; then
					best_dir="$dir"
					best_score="$score"
				fi
			elif [[ -z "$best_dir" ]]; then
				best_dir="$dir"
			fi
		fi
	done < <(profile_dirs)

	if [[ -n "$best_dir" ]]; then
		printf '%s\n' "$best_dir"
		return 0
	fi

	if [[ -n "${CLAUDE_CONFIG_DIR:-}" && -d "${CLAUDE_CONFIG_DIR:-}" ]]; then
		printf '%s\n' "$CLAUDE_CONFIG_DIR"
		return 0
	fi

	printf '%s\n' "$HOME/.claude"
}

build_attempt_list() {
	local start_dir="$1"
	local dir
	local -a dirs=()

	dirs+=("$start_dir")
	while IFS= read -r dir; do
		[[ "$dir" == "$start_dir" ]] && continue
		dirs+=("$dir")
	done < <(profile_dirs)

	printf '%s\n' "${dirs[@]}"
}

limit_hit() {
	local transcript="$1"
	[[ -f "$transcript" ]] || return 1
	grep -Eqi "you've hit your limit|/extra-usage|usage limit|rate limit reached|plan usage limit" "$transcript"
}

run_interactive() {
	local transcript="$1"
	shift

	if [[ ! -t 0 || ! -t 1 ]]; then
		"$CLAUDE_BIN" "$@"
		return $?
	fi

	if script --version >/dev/null 2>&1; then
		local cmd_string=""
		local arg
		for arg in "$@"; do
			printf -v arg '%q' "$arg"
			cmd_string+="$arg "
		done
		script -qefc "$cmd_string" "$transcript"
		return $?
	fi

	script -q "$transcript" "$CLAUDE_BIN" "$@"
}

main() {
	local start_dir
	local current_dir
	local transcript
	local exit_code
	local -a attempts=()
	local attempt

	start_dir="$(choose_start_profile)"
	while IFS= read -r attempt; do
		attempts+=("$attempt")
	done < <(build_attempt_list "$start_dir")

	for current_dir in "${attempts[@]}"; do
		export CLAUDE_CONFIG_DIR="$current_dir"
		printf '%s\n' "$current_dir" >"$STATE_FILE"
		log "claude-rotate: using profile '$(profile_label "$current_dir")'"

		if ! test -x "$USAGE_CHECK_SCRIPT" || usage_available "$current_dir"; then
			transcript="$(mktemp -t claude-rotate.XXXXXX)"
			if run_interactive "$transcript" "$@"; then
				rm -f "$transcript"
				return 0
			fi
			exit_code=$?

			if limit_hit "$transcript"; then
				rm -f "$transcript"
				log "claude-rotate: profile '$(profile_label "$current_dir")' hit its limit, trying next profile"
				continue
			fi

			rm -f "$transcript"
			return $exit_code
		fi

		log "claude-rotate: profile '$(profile_label "$current_dir")' is already at its usage threshold"
	done

	log "claude-rotate: all Claude profiles are exhausted"
	return 1
}

main "$@"
