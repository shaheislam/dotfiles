#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
workspace-manifest.sh - inspect or execute workspace manifest commands

USAGE:
  scripts/workspace-manifest.sh [info|command|exec] [phase] [options]

COMMANDS:
  info              Show manifest summary (default)
  command <phase>   Print the command configured for a phase (setup|run|archive)
  exec <phase>      Execute the phase command from within the worktree

OPTIONS:
  --worktree PATH   Worktree/checkout to run against (defaults to git root or $PWD)
  --manifest FILE   Explicit manifest path (defaults to .workspace-manifest.json in worktree)
  --json            Emit info output as compact JSON (info command only)
  --help            Show this help text

Examples:
  scripts/workspace-manifest.sh info
  scripts/workspace-manifest.sh command run
  scripts/workspace-manifest.sh exec setup --worktree ~/dotfiles/dotfiles-conductor
EOF
}

require_tool() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Error: $1 is required for workspace-manifest.sh" >&2
		exit 1
	fi
}

ACTION="info"
PHASE=""
WORKTREE_OVERRIDE=""
MANIFEST_OVERRIDE=""
INFO_JSON=false

while [[ $# -gt 0 ]]; do
	case $1 in
	info | command | exec)
		ACTION="$1"
		shift
		if [[ "$ACTION" != "info" ]]; then
			if [[ $# -gt 0 && "$1" != --* ]]; then
				PHASE="$1"
				shift
			fi
		fi
		;;
	--phase)
		shift
		PHASE="${1:-}"
		if [[ -z "$PHASE" ]]; then
			echo "Error: --phase requires a value" >&2
			exit 1
		fi
		shift
		;;
	--worktree)
		shift
		WORKTREE_OVERRIDE="${1:-}"
		if [[ -z "$WORKTREE_OVERRIDE" ]]; then
			echo "Error: --worktree requires a path" >&2
			exit 1
		fi
		shift
		;;
	--manifest)
		shift
		MANIFEST_OVERRIDE="${1:-}"
		if [[ -z "$MANIFEST_OVERRIDE" ]]; then
			echo "Error: --manifest requires a path" >&2
			exit 1
		fi
		shift
		;;
	--json)
		INFO_JSON=true
		shift
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		echo "Error: unknown argument $1" >&2
		usage
		exit 1
		;;
	esac
done

if [[ "$ACTION" != "info" && -z "$PHASE" ]]; then
	echo "Error: phase name required (setup|run|archive)" >&2
	usage
	exit 1
fi

require_tool jq

resolve_worktree() {
	if [[ -n "$WORKTREE_OVERRIDE" ]]; then
		if [[ -d "$WORKTREE_OVERRIDE" ]]; then
			(cd "$WORKTREE_OVERRIDE" && pwd)
			return
		else
			echo "Error: worktree path not found: $WORKTREE_OVERRIDE" >&2
			exit 1
		fi
	fi

	if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
		echo "$git_root"
	else
		pwd
	fi
}

WORKTREE_PATH=$(resolve_worktree)

resolve_manifest() {
	if [[ -n "$MANIFEST_OVERRIDE" ]]; then
		if [[ -f "$MANIFEST_OVERRIDE" ]]; then
			echo "$MANIFEST_OVERRIDE"
			return
		else
			echo "Error: manifest file not found: $MANIFEST_OVERRIDE" >&2
			exit 1
		fi
	fi

	local candidate
	candidate="$WORKTREE_PATH/.workspace-manifest.json"
	if [[ -f "$candidate" ]]; then
		echo "$candidate"
		return
	fi

	candidate="$WORKTREE_PATH/workspace-manifest.json"
	if [[ -f "$candidate" ]]; then
		echo "$candidate"
		return
	fi

	if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
		candidate="$git_root/.workspace-manifest.json"
		if [[ -f "$candidate" ]]; then
			echo "$candidate"
			return
		fi
	fi

	echo "Error: no workspace manifest found (expected .workspace-manifest.json)" >&2
	exit 1
}

MANIFEST_PATH=$(resolve_manifest)

print_info_text() {
	local mode
	mode=$(jq -r '.runScriptMode // ""' "$MANIFEST_PATH")
	echo "Manifest: $MANIFEST_PATH"
	echo "Worktree: $WORKTREE_PATH"
	if [[ -n "$mode" ]]; then
		echo "Run Script Mode: $mode"
	fi
	echo "Scripts:"
	jq -r '.scripts // {} | to_entries[] | "  - " + .key + ": " + .value' "$MANIFEST_PATH"
	local notes
	notes=$(jq -r '.notes // empty' "$MANIFEST_PATH")
	if [[ -n "$notes" ]]; then
		echo "Notes:"
		jq -r '.notes[] | "  - " + .' "$MANIFEST_PATH"
	fi
}

print_info_json() {
	jq -c --arg manifest "$MANIFEST_PATH" --arg worktree "$WORKTREE_PATH" '{manifest: $manifest, worktree: $worktree, runScriptMode: (.runScriptMode // null), scripts: (.scripts // {}), notes: (.notes // [])}' "$MANIFEST_PATH"
}

get_phase_command() {
	local phase="$1"
	local cmd
	cmd=$(jq -r --arg phase "$phase" '.scripts[$phase] // empty' "$MANIFEST_PATH")
	if [[ -z "$cmd" ]]; then
		echo "Error: phase '$phase' not defined in $MANIFEST_PATH" >&2
		exit 1
	fi
	printf '%s\n' "$cmd"
}

run_phase_command() {
	local phase="$1"
	local cmd
	cmd=$(get_phase_command "$phase")
	echo "[workspace-manifest] ($phase) $cmd"
	(cd "$WORKTREE_PATH" && eval "$cmd")
}

case $ACTION in
info)
	if $INFO_JSON; then
		print_info_json
	else
		print_info_text
	fi
	;;
command)
	get_phase_command "$PHASE"
	;;
exec)
	run_phase_command "$PHASE"
	;;
*)
	usage
	exit 1
	;;
esac
