#!/usr/bin/env bash
# Run the Skill TOIL audit at most once per calendar month on this device.
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"
AUDIT_SCRIPT="$DOTFILES_ROOT/scripts/opencode/skill-toil-audit.py"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/skill-toil-audit"
LOG_DIR="$STATE_DIR"
LOCAL_MARKER="$STATE_DIR/last-run-month"
MONTH="$(date +%Y-%m)"
HOSTNAME_SAFE="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
HOSTNAME_SAFE="$(printf '%s' "$HOSTNAME_SAFE" | tr -c '[:alnum:]_.-' '-')"
WINDOW_NAME="skill-toil-$MONTH"
TMUX_TARGET="${SKILL_TOIL_AUDIT_TMUX_TARGET:-}"
FORCE=false
NO_TMUX=false
DRY_RUN=false

usage() {
    cat <<EOF
Usage: skill-toil-audit-monthly.sh [--force] [--no-tmux] [--dry-run]

Runs scripts/opencode/skill-toil-audit.py with low-impact monthly defaults:
  --days 30 --min-count 3 --limit 20

The local guard is per-device and lives at:
  $LOCAL_MARKER
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --force)
        FORCE=true
        shift
        ;;
    --no-tmux)
        NO_TMUX=true
        shift
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    *)
        printf 'Unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
done

report_path() {
    if [[ -d "$HOME/obsidian" ]]; then
        printf '%s\n' "$HOME/obsidian/Claude/Audit/skill-toil/$HOSTNAME_SAFE/skill-toil-$MONTH.md"
    else
        printf '%s\n' "$STATE_DIR/reports/skill-toil-$MONTH.md"
    fi
}

already_ran() {
    [[ "$FORCE" == false && -f "$LOCAL_MARKER" && "$(<"$LOCAL_MARKER")" == "$MONTH" ]]
}

ensure_dirs() {
    mkdir -p "$STATE_DIR" "$LOG_DIR" "$(dirname "$(report_path)")"
}

tmux_available() {
    [[ "$NO_TMUX" == false && -z "${SKILL_TOIL_AUDIT_IN_TMUX:-}" ]] || return 1
    command -v tmux >/dev/null 2>&1 || return 1
    tmux list-sessions >/dev/null 2>&1 || return 1
}

first_tmux_session() {
    tmux list-sessions -F '#{session_name}' 2>/dev/null | sed -n '1p'
}

spawn_tmux_window() {
    local session_name command_text inner_command escaped_inner
    session_name="${TMUX_TARGET:-$(first_tmux_session)}"
    [[ -n "$session_name" ]] || return 1

    if tmux list-windows -t "$session_name" -F '#{window_name}' 2>/dev/null | grep -Fxq "$WINDOW_NAME"; then
        printf 'Skill TOIL audit tmux window already exists: %s:%s\n' "$session_name" "$WINDOW_NAME"
        return 0
    fi

    inner_command="cd \"$DOTFILES_ROOT\" && SKILL_TOIL_AUDIT_IN_TMUX=1 \"$0\" --no-tmux"
    if [[ "$FORCE" == true ]]; then
        inner_command="$inner_command --force"
    fi
    inner_command="$inner_command; printf '\nReport complete. Press Enter to close this window. '; read -r _"
    escaped_inner="${inner_command//\'/\'\\\'\'}"
    command_text="/bin/bash -lc '$escaped_inner'"

    tmux new-window -t "$session_name:" -n "$WINDOW_NAME" "$command_text"
}

run_audit() {
    local report
    report="$(report_path)"

    if [[ "$DRY_RUN" == true ]]; then
        printf 'DRY RUN: would write report to %s\n' "$report"
        printf 'DRY RUN: would update marker %s to %s\n' "$LOCAL_MARKER" "$MONTH"
        return 0
    fi

    python3 "$AUDIT_SCRIPT" --days 30 --min-count 3 --limit 20 --save "$report"
    printf '%s\n' "$MONTH" >"$LOCAL_MARKER"
    printf '\nReport written: %s\n' "$report"
    printf 'Monthly marker updated: %s\n' "$LOCAL_MARKER"
}

main() {
    ensure_dirs

    if already_ran; then
        printf 'Skill TOIL audit already ran on this device for %s.\n' "$MONTH"
        printf 'Marker: %s\n' "$LOCAL_MARKER"
        return 0
    fi

    if [[ ! -f "$AUDIT_SCRIPT" ]]; then
        printf 'Audit script not found: %s\n' "$AUDIT_SCRIPT" >&2
        return 1
    fi

    if tmux_available; then
        printf 'Opening tmux window %s for monthly Skill TOIL audit.\n' "$WINDOW_NAME"
        spawn_tmux_window
        return 0
    fi

    run_audit
}

main "$@"
