#!/usr/bin/env bash
# Run executable success criteria from a living .plan.md.
#
# Usage: plan-validate-criteria.sh [plan.md] [--summary]
#
# Extracts fenced bash/sh blocks from the `## Success Criteria` section and
# runs each from the plan file's directory. Non-code criteria are reported as
# MANUAL so the agent knows to inspect them instead of treating them as passed.
set -euo pipefail

usage() {
	echo "Usage: plan-validate-criteria.sh [plan.md] [--summary]" >&2
	echo "Runs bash/sh code blocks from the ## Success Criteria section." >&2
}

summary=0
plan_file=""

for arg in "$@"; do
	case "$arg" in
	--summary)
		summary=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		if [[ -n "$plan_file" ]]; then
			usage
			exit 2
		fi
		plan_file="$arg"
		;;
	esac
done

if [[ -z "$plan_file" ]]; then
	repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
	plan_file="$repo_root/.plan.md"
fi

if [[ ! -f "$plan_file" ]]; then
	echo "FAIL: plan file not found: $plan_file" >&2
	exit 2
fi

plan_file=$(cd "$(dirname "$plan_file")" && pwd)/$(basename "$plan_file")
plan_dir=$(dirname "$plan_file")
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

awk -v out="$tmpdir" '
    BEGIN {
        in_section = 0
        in_block = 0
        block_count = 0
        section_found = 0
    }

    /^##[[:space:]]+/ {
        heading = tolower($0)
        sub(/^##[[:space:]]+/, "", heading)

        if (in_section && !in_block) {
            exit
        }

        if (heading ~ /^success criteria([[:space:]]|$)/) {
            in_section = 1
            section_found = 1
            next
        }
    }

    in_section && /^```[[:space:]]*(bash|sh)[[:space:]]*$/ {
        in_block = 1
        block_count += 1
        file = sprintf("%s/block-%03d.sh", out, block_count)
        next
    }

    in_section && in_block && /^```[[:space:]]*$/ {
        close(file)
        in_block = 0
        next
    }

    in_section && in_block {
        print > file
    }

    END {
        print block_count > (out "/count")
        print section_found > (out "/section_found")
    }
' "$plan_file"

block_count=$(<"$tmpdir/count")
section_found=$(<"$tmpdir/section_found")

if [[ "$section_found" -eq 0 ]]; then
	if [[ "$summary" -eq 1 ]]; then
		echo "MANUAL: no ## Success Criteria section in $plan_file"
	else
		echo "MANUAL: no ## Success Criteria section found in $plan_file"
	fi
	exit 0
fi

if [[ "$block_count" -eq 0 ]]; then
	if [[ "$summary" -eq 1 ]]; then
		echo "MANUAL: no bash criteria in $plan_file"
	else
		echo "MANUAL: ## Success Criteria has no bash/sh code blocks in $plan_file"
		echo "Review the written criteria manually before claiming completion."
	fi
	exit 0
fi

show_output() {
	local file="$1"
	if [[ ! -s "$file" ]]; then
		return 0
	fi

	awk '
        NR <= 40 { print "    " $0 }
        NR == 41 { print "    ... output truncated after 40 lines" }
    ' "$file"
}

passed=0
failed=0

for ((i = 1; i <= block_count; i += 1)); do
	block_file=$(printf '%s/block-%03d.sh' "$tmpdir" "$i")
	output_file=$(printf '%s/block-%03d.out' "$tmpdir" "$i")

	if (cd "$plan_dir" && bash "$block_file") >"$output_file" 2>&1; then
		passed=$((passed + 1))
		if [[ "$summary" -eq 0 ]]; then
			echo "PASS: success criterion block $i"
			show_output "$output_file"
		fi
	else
		failed=$((failed + 1))
		if [[ "$summary" -eq 0 ]]; then
			echo "FAIL: success criterion block $i" >&2
			show_output "$output_file" >&2
		fi
	fi
done

if [[ "$failed" -eq 0 ]]; then
	if [[ "$summary" -eq 1 ]]; then
		echo "PASS: $passed/$block_count executable success criteria passed"
	else
		echo "PASS: $passed/$block_count executable success criteria passed for $plan_file"
	fi
	exit 0
fi

if [[ "$summary" -eq 1 ]]; then
	echo "FAIL: $failed/$block_count executable success criteria failed"
else
	echo "FAIL: $failed/$block_count executable success criteria failed for $plan_file" >&2
fi
exit 1
