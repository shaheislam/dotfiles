#!/usr/bin/env bash
# worktree-setup-steps.sh — Structured worktree setup with step tracking
#
# Inspired by superset-sh/superset's .superset/lib/setup/steps.sh pattern.
# Runs numbered setup steps with skip/failure tracking and summary output.
#
# Each step is idempotent and tracks its completion. Re-running skips
# already-completed steps unless --force is used.
#
# Usage:
#   worktree-setup-steps.sh <worktree-path> [--force] [--step N] [--dry-run]
#   worktree-setup-steps.sh <worktree-path> --status
#   worktree-setup-steps.sh <worktree-path> --reset

set -euo pipefail

WORKTREE_PATH=""
FORCE=false
ONLY_STEP=""
DRY_RUN=false
SHOW_STATUS=false
RESET=false

for arg in "$@"; do
    case "$arg" in
    --force) FORCE=true ;;
    --dry-run) DRY_RUN=true ;;
    --status) SHOW_STATUS=true ;;
    --reset) RESET=true ;;
    --step)
        # Next arg is step number (handled below)
        ;;
    --step=*) ONLY_STEP="${arg#--step=}" ;;
    *)
        if [ -z "$WORKTREE_PATH" ]; then
            WORKTREE_PATH="$arg"
        elif [ -z "$ONLY_STEP" ] && [[ "$arg" =~ ^[0-9]+$ ]]; then
            ONLY_STEP="$arg"
        fi
        ;;
    esac
done

if [ -z "$WORKTREE_PATH" ]; then
    echo "Usage: worktree-setup-steps.sh <worktree-path> [--force] [--step N]"
    exit 1
fi

WORKTREE_PATH=$(realpath "$WORKTREE_PATH" 2>/dev/null || echo "$WORKTREE_PATH")
STATE_DIR="$WORKTREE_PATH/.claude"
STATE_FILE="$STATE_DIR/setup-steps.json"

# --- State tracking ---
ensure_state() {
    mkdir -p "$STATE_DIR"
    if [ ! -f "$STATE_FILE" ]; then
        echo '{"steps": {}, "last_run": null}' >"$STATE_FILE"
    fi
}

mark_step() {
    local step="$1" status="$2"
    ensure_state
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local tmp
    tmp=$(jq --arg s "$step" --arg st "$status" --arg t "$now" \
        '.steps[$s] = { status: $st, timestamp: $t } | .last_run = $t' "$STATE_FILE")
    echo "$tmp" >"$STATE_FILE"
}

step_status() {
    local step="$1"
    ensure_state
    jq -r --arg s "$step" '.steps[$s].status // "pending"' "$STATE_FILE"
}

if $RESET; then
    rm -f "$STATE_FILE"
    echo "Reset setup state for $WORKTREE_PATH"
    exit 0
fi

# --- Step definitions ---
# Each step: step_N() function + STEP_NAMES[N] description
declare -a STEP_NAMES
# shellcheck disable=SC2034
declare -a STEP_FUNCS

STEP_NAMES[1]="Trust mise config"
step_1() {
    if command -v mise >/dev/null 2>&1; then
        if [ -f "$WORKTREE_PATH/mise.toml" ] || [ -f "$WORKTREE_PATH/.mise.toml" ]; then
            mise trust "$WORKTREE_PATH" 2>/dev/null || true
            return 0
        fi
    fi
    return 0 # Not an error if mise isn't present
}

STEP_NAMES[2]="Run project setup script"
step_2() {
    local setup_script=""
    if [ -f "$WORKTREE_PATH/.devcontainer/setup.sh" ]; then
        setup_script="$WORKTREE_PATH/.devcontainer/setup.sh"
    elif [ -f "$WORKTREE_PATH/scripts/setup-worktree.sh" ]; then
        setup_script="$WORKTREE_PATH/scripts/setup-worktree.sh"
    fi

    if [ -n "$setup_script" ]; then
        echo "   Running: $setup_script"
        (cd "$WORKTREE_PATH" && bash "$setup_script")
        return $?
    fi
    return 0 # No setup script is fine
}

STEP_NAMES[3]="Sync agent commands"
step_3() {
    local sync_script="$HOME/dotfiles/scripts/sync-agent-commands.sh"
    if [ -x "$sync_script" ] && [ -d "$WORKTREE_PATH/.agents/commands" ]; then
        bash "$sync_script" "$WORKTREE_PATH"
        return $?
    fi
    return 0
}

STEP_NAMES[4]="Sync MCP config"
step_4() {
    local mcp_sync="$HOME/dotfiles/scripts/sync-mcp-config.sh"
    if [ -x "$mcp_sync" ] && [ -f "$WORKTREE_PATH/.mcp.json" ]; then
        bash "$mcp_sync" "$WORKTREE_PATH"
        return $?
    fi
    return 0
}

STEP_NAMES[5]="Allocate port range"
step_5() {
    local allocator="$HOME/dotfiles/scripts/port-allocator.sh"
    if [ -x "$allocator" ]; then
        # Derive instance name from worktree path
        local wt_name
        wt_name=$(basename "$WORKTREE_PATH")
        local base_port
        base_port=$(bash "$allocator" allocate "$wt_name" 2>/dev/null)
        if [ -n "$base_port" ]; then
            echo "   Port range: $base_port-$((base_port + 19))"
            # Write a .env.ports file for easy sourcing
            bash "$allocator" env "$wt_name" >"$WORKTREE_PATH/.env.ports" 2>/dev/null || true
        fi
    fi
    return 0
}

STEP_NAMES[6]="Initialize beads"
step_6() {
    if command -v bd >/dev/null 2>&1; then
        (cd "$WORKTREE_PATH" && bd prime 2>/dev/null) || true
    fi
    return 0
}

TOTAL_STEPS=6

# --- Show status ---
if $SHOW_STATUS; then
    ensure_state
    echo "Setup status for: $WORKTREE_PATH"
    echo ""
    for ((i = 1; i <= TOTAL_STEPS; i++)); do
        local_status=$(step_status "$i")
        case "$local_status" in
        done) icon="[done]" ;;
        failed) icon="[FAIL]" ;;
        skipped) icon="[skip]" ;;
        *) icon="[    ]" ;;
        esac
        printf "  %s Step %d: %s\n" "$icon" "$i" "${STEP_NAMES[$i]}"
    done
    exit 0
fi

# --- Execute steps ---
echo "Setting up worktree: $(basename "$WORKTREE_PATH")"
echo ""

passed=0
failed=0
skipped=0

for ((i = 1; i <= TOTAL_STEPS; i++)); do
    # Skip if not the requested step
    if [ -n "$ONLY_STEP" ] && [ "$i" != "$ONLY_STEP" ]; then
        continue
    fi

    step_name="${STEP_NAMES[$i]}"
    current_status=$(step_status "$i")

    # Skip already completed unless forced
    if [ "$current_status" = "done" ] && ! $FORCE; then
        printf "  [skip] Step %d: %s (already done)\n" "$i" "$step_name"
        skipped=$((skipped + 1))
        continue
    fi

    if $DRY_RUN; then
        printf "  [    ] Step %d: %s (would run)\n" "$i" "$step_name"
        continue
    fi

    # Run the step
    printf "  [....] Step %d: %s" "$i" "$step_name"
    if "step_$i" 2>&1; then
        printf "\r  [done] Step %d: %s\n" "$i" "$step_name"
        mark_step "$i" "done"
        passed=$((passed + 1))
    else
        printf "\r  [FAIL] Step %d: %s\n" "$i" "$step_name"
        mark_step "$i" "failed"
        failed=$((failed + 1))
    fi
done

echo ""
echo "Summary: $passed passed, $failed failed, $skipped skipped"

if [ "$failed" -gt 0 ]; then
    echo "Re-run failed steps with: worktree-setup-steps.sh $WORKTREE_PATH --force"
    exit 1
fi
