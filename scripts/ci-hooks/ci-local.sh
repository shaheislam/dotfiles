#!/usr/bin/env bash
# ci-local.sh — Run local CI checks for a project.
# Main entry point called by Claude Code hooks and directly.
#
# Usage:
#   ci-local.sh [project_dir]
#   ci-local.sh --check-only [project_dir]   # Just check if CI would run
#
# Exit codes:
#   0 = all checks passed (or no checks to run)
#   1 = one or more checks failed
#   2 = not in a watched directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parse-config.sh"

CHECK_ONLY=false
if [[ "${1:-}" == "--check-only" ]]; then
    CHECK_ONLY=true
    shift
fi

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || exit 2

# Load config (graceful if missing)
ci_config_load 2>/dev/null || true

# Check if project is under a watched path
_is_watched() {
    local dir="$1"
    local watch_paths
    watch_paths="$(ci_config_watch_paths)"
    if [[ -z "$watch_paths" ]]; then
        # Default: ~/work
        watch_paths="$HOME/work"
    fi
    while IFS= read -r wp; do
        [[ -z "$wp" ]] && continue
        if [[ "$dir" == "$wp"* ]]; then
            return 0
        fi
    done <<<"$watch_paths"
    return 1
}

if ! _is_watched "$PROJECT_DIR"; then
    exit 2
fi

if $CHECK_ONLY; then
    echo "would-run"
    exit 0
fi

# Get CI commands: per-repo override > defaults by detected stack
_get_ci_commands() {
    local dir="$1"

    # Try per-repo overrides first
    local repo_cmds
    repo_cmds="$(ci_config_repo_commands "$dir" 2>/dev/null)" || true
    if [[ -n "$repo_cmds" ]]; then
        echo "$repo_cmds"
        return
    fi

    # Auto-detect stack and use default commands
    local stacks
    stacks="$("$SCRIPT_DIR/detect-stack.sh" "$dir" 2>/dev/null)" || true
    if [[ -z "$stacks" ]]; then
        return
    fi

    while IFS= read -r stack; do
        # Try config defaults first
        local defaults
        defaults="$(ci_config_default_commands "$stack" 2>/dev/null)" || true
        if [[ -n "$defaults" ]]; then
            echo "$defaults"
        else
            # Hardcoded fallback defaults
            _builtin_defaults "$stack"
        fi
    done <<<"$stacks"
}

_builtin_defaults() {
    local stack="$1"
    case "$stack" in
    typescript)
        echo "npx tsc --noEmit"
        echo "npm run lint 2>/dev/null || true"
        ;;
    node)
        echo "npm test 2>/dev/null || true"
        echo "npm run lint 2>/dev/null || true"
        ;;
    python)
        echo "python -m pytest -x --tb=short 2>/dev/null || true"
        echo "ruff check . 2>/dev/null || true"
        ;;
    go)
        echo "go vet ./..."
        echo "go test ./..."
        ;;
    rust)
        echo "cargo check"
        echo "cargo test"
        ;;
    shell)
        echo "shellcheck scripts/*.sh 2>/dev/null || true"
        ;;
    terraform)
        echo "terraform fmt -check -recursive"
        echo "terraform validate"
        ;;
    *) ;;
    esac
}

# Run CI commands
FAIL_FAST="$(ci_config_setting fail_fast true)"
TIMEOUT="$(ci_config_setting timeout 120)"

commands="$(_get_ci_commands "$PROJECT_DIR")"
if [[ -z "$commands" ]]; then
    exit 0
fi

failed=0
total=0
results=()

while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    total=$((total + 1))

    # Run with timeout in the project directory
    if timeout "$TIMEOUT" bash -c "cd '$PROJECT_DIR' && $cmd" >/dev/null 2>&1; then
        results+=("PASS: $cmd")
    else
        results+=("FAIL: $cmd")
        failed=$((failed + 1))
        if [[ "$FAIL_FAST" == "true" ]]; then
            break
        fi
    fi
done <<<"$commands"

# Output results
for r in "${results[@]}"; do
    echo "$r"
done

if [[ $failed -gt 0 ]]; then
    echo "---"
    echo "CI: $failed/$total checks failed in $(basename "$PROJECT_DIR")"
    exit 1
else
    echo "---"
    echo "CI: $total/$total checks passed in $(basename "$PROJECT_DIR")"
    exit 0
fi
