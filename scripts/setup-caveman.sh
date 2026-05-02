#!/usr/bin/env bash
# setup-caveman.sh - Optional, minimal Caveman integration for AI harnesses.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false
CLAUDE_ONLY=false
OPENCODE_ONLY=false

usage() {
    cat <<'EOF'
Usage: scripts/setup-caveman.sh [--dry-run] [--claude-only|--opencode-only]

Installs Caveman as an explicit, on-demand capability. This intentionally avoids
always-on repo rules, hooks, statusline wiring, and MCP shrink middleware.

What it does:
  - Syncs the local dotfiles `caveman` skill into harness skill directories
  - Installs the Claude Code Caveman plugin when `claude` exists
  - Installs the OpenCode Caveman skill profile via `bunx skills` when available

Activation stays explicit: use `/caveman`, `/skill caveman`, or compact commands.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --claude-only)
        CLAUDE_ONLY=true
        shift
        ;;
    --opencode-only)
        OPENCODE_ONLY=true
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
    esac
done

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_or_print() {
    if [[ "$DRY_RUN" == "true" ]]; then
        printf 'DRY RUN: %s\n' "$*"
    else
        "$@"
    fi
}

if [[ "$CLAUDE_ONLY" == "true" && "$OPENCODE_ONLY" == "true" ]]; then
    printf 'Choose only one of --claude-only or --opencode-only\n' >&2
    exit 2
fi

if [[ -x "$DOTFILES_ROOT/scripts/sync-skills-harnesses.sh" ]]; then
    run_or_print "$DOTFILES_ROOT/scripts/sync-skills-harnesses.sh"
fi

if [[ "$OPENCODE_ONLY" != "true" ]]; then
    if command_exists claude; then
        run_or_print claude plugin marketplace add JuliusBrussee/caveman
        run_or_print claude plugin install caveman@caveman
    else
        printf 'WARN: claude not found; skipping Claude Code Caveman plugin\n' >&2
    fi
fi

if [[ "$CLAUDE_ONLY" != "true" ]]; then
    if command_exists bun; then
        run_or_print bunx skills add JuliusBrussee/caveman -a opencode
    else
        printf 'WARN: bun not found; skipping OpenCode Caveman skill install\n' >&2
    fi
fi

printf 'Caveman available on demand. Use /caveman, /skill caveman, or compact OpenCode commands.\n'
