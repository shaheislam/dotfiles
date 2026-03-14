#!/usr/bin/env bash
# aimux log - view agent output logs

_log_workspace=""
_log_follow=false
_log_all=false
_log_clear=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --follow | -f)
        _log_follow=true
        shift
        ;;
    --all | -a)
        _log_all=true
        shift
        ;;
    --clear)
        _log_clear=true
        shift
        ;;
    -h | --help)
        cat <<'HELP'
Usage: aimux log [options] [workspace]

View logs from agent execution

Options:
  -f, --follow     Follow log output (like tail -f)
  -a, --all        Show logs from all workspaces
  --clear          Clear log files
  -h, --help       Show this help

Log files are stored in ~/.aimux/logs/<workspace>.log
HELP
        exit 0
        ;;
    -*) die "Unknown option: $1" ;;
    *)
        _log_workspace="$1"
        shift
        ;;
    esac
done

AIMUX_LOG_DIR="${AIMUX_LOG_DIR:-$AIMUX_HOME/logs}"

# Clear mode
if $_log_clear; then
    if $_log_all; then
        rm -f "$AIMUX_LOG_DIR"/*.log 2>/dev/null || true
        info "Cleared all log files"
    elif [[ -n "$_log_workspace" ]]; then
        rm -f "$AIMUX_LOG_DIR/${_log_workspace}.log" 2>/dev/null || true
        info "Cleared log for $_log_workspace"
    else
        die "Specify a workspace or use --all with --clear"
    fi
    exit 0
fi

# All mode: interleave all logs
if $_log_all; then
    if ! ls "$AIMUX_LOG_DIR"/*.log &>/dev/null; then
        info "No log files found in $AIMUX_LOG_DIR"
        exit 0
    fi
    if $_log_follow; then
        tail -f "$AIMUX_LOG_DIR"/*.log
    else
        for logfile in "$AIMUX_LOG_DIR"/*.log; do
            [[ -f "$logfile" ]] || continue
            local_name="$(basename "$logfile" .log)"
            printf "${BOLD}=== %s ===${RESET}\n" "$local_name"
            tail -50 "$logfile"
            echo
        done
    fi
    exit 0
fi

# Single workspace mode
if [[ -z "$_log_workspace" ]]; then
    # Try to detect from current directory
    root="$(git_root)"
    if [[ -n "$root" ]]; then
        branch="$(git_branch)"
        repo_name="$(basename "$root")"
        _log_workspace="${repo_name}-${branch//\//-}"
    fi
fi

[[ -z "$_log_workspace" ]] && die "Usage: aimux log [workspace] (or run from a git worktree)"

_log_file="$AIMUX_LOG_DIR/${_log_workspace}.log"

if [[ ! -f "$_log_file" ]]; then
    # Try partial match
    _match="$(ls "$AIMUX_LOG_DIR"/*"${_log_workspace}"*.log 2>/dev/null | head -1 || true)"
    if [[ -n "$_match" ]]; then
        _log_file="$_match"
    else
        die "No log file found for workspace: $_log_workspace"
    fi
fi

if $_log_follow; then
    tail -f "$_log_file"
else
    tail -100 "$_log_file"
fi
