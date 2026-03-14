#!/usr/bin/env bash
# aimux new - create workspace (worktree + tmux window)

_new_branch=""
_new_create=false
_new_no_devcon=false
_new_exec=false
_new_rebuild=false
_new_fast=false
_new_mounts=()
_new_features=""
_new_repo=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --new | -n)
        _new_create=true
        shift
        ;;
    --no-devcon)
        _new_no_devcon=true
        shift
        ;;
    --exec | -e)
        _new_exec=true
        shift
        ;;
    --rebuild | -r)
        _new_rebuild=true
        shift
        ;;
    --fast | -f)
        _new_fast=true
        shift
        ;;
    --mount | -m)
        _new_mounts+=("$2")
        shift 2
        ;;
    --features | -F)
        _new_features="$2"
        shift 2
        ;;
    --repo)
        _new_repo="$2"
        shift 2
        ;;
    -h | --help)
        cat <<'HELP'
Usage: aimux new [options] <branch>

Create a workspace: git worktree + tmux window + optional devcontainer

Options:
  -n, --new           Create new branch (even if it doesn't exist)
  -e, --exec          Enter container shell after start
  -m, --mount DIR     Additional directory mount (repeatable)
  -F, --features LIST Comma-separated devcontainer features
  --repo DIR          Git repo directory (instead of detecting from cwd)
  --no-devcon         Skip devcontainer
  --rebuild           Remove + rebuild devcontainer
  --fast              Skip devcontainer lifecycle hooks
  -h, --help          Show this help
HELP
        exit 0
        ;;
    -*) die "Unknown option: $1" ;;
    *)
        _new_branch="$1"
        shift
        ;;
    esac
done

[[ -z "$_new_branch" ]] && die "Usage: aimux new <branch>"
require git
require tmux

# Resolve repo root
if [[ -n "$_new_repo" ]]; then
    root="$(cd "$_new_repo" && git_root)"
    [[ -z "$root" ]] && die "Not a git repository: $_new_repo"
else
    root="$(git_root)"
    [[ -z "$root" ]] && die "Not in a git repository"
fi

repo_name="$(basename "$root")"

# Worktree path: ../repo-branch
wt_dir="$(dirname "$root")/${repo_name}-${_new_branch}"
instance_name="${repo_name}-${_new_branch//\//-}"

# Check if worktree already exists
if [[ -d "$wt_dir" ]]; then
    info "Worktree already exists: $wt_dir"
else
    if $_new_create; then
        info "Creating new branch: $_new_branch"
        git worktree add -b "$_new_branch" "$wt_dir" || die "Failed to create worktree"
    else
        # Auto-detect: existing branch or create new
        if git show-ref --verify --quiet "refs/heads/$_new_branch" 2>/dev/null ||
            git show-ref --verify --quiet "refs/remotes/origin/$_new_branch" 2>/dev/null; then
            info "Checking out existing branch: $_new_branch"
            git worktree add "$wt_dir" "$_new_branch" || die "Failed to create worktree"
        else
            info "Creating new branch: $_new_branch"
            git worktree add -b "$_new_branch" "$wt_dir" || die "Failed to create worktree"
        fi
    fi
fi

# Trust mise if present
if has mise && [[ -f "$wt_dir/.mise.toml" || -f "$wt_dir/.tool-versions" ]]; then
    (cd "$wt_dir" && mise trust 2>/dev/null || true)
fi

# Create tmux window if in tmux
if in_tmux; then
    session="$(tmux_session)"
    existing=$(tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -x "$_new_branch" || true)

    if [[ -z "$existing" ]]; then
        tmux new-window -t "$session" -n "$_new_branch" -c "$wt_dir"
        info "Created tmux window: $_new_branch"
    else
        info "tmux window already exists for $_new_branch"
    fi
fi

# Devcontainer (if available and not skipped)
if ! $_new_no_devcon && has devcon; then
    devcon_args=("--name" "$instance_name")
    $_new_rebuild && devcon_args+=("--rebuild")
    $_new_fast && devcon_args+=("--skip-hooks")
    [[ -n "$_new_features" ]] && devcon_args+=("--features" "$_new_features")
    for mount in "${_new_mounts[@]}"; do
        rp="$(realpath "$mount" 2>/dev/null || echo "$mount")"
        [[ -d "$rp" ]] && devcon_args+=("--mount" "$rp")
    done
    info "Starting devcontainer: $instance_name"
    (cd "$wt_dir" && devcon up "${devcon_args[@]}" 2>&1) || warn "devcontainer failed (continuing without)"
elif ! $_new_no_devcon && ! has devcon; then
    : # silently skip if devcon not available
fi

# Write state file
ensure_home
state_write "$instance_name" \
    status=active \
    branch="$_new_branch" \
    worktree="$wt_dir" \
    repo="$root" \
    created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    provider="" \
    ticket=""

# Start tmux pipe-pane logging
if in_tmux && [[ -n "${session:-}" ]]; then
    mkdir -p "$AIMUX_LOG_DIR"
    tmux pipe-pane -t "$session:$_new_branch" "cat >> $AIMUX_LOG_DIR/${instance_name}.log" 2>/dev/null || true
fi

# Summary
printf "\n${BOLD}Workspace ready${RESET}\n"
printf "  Branch:    %s\n" "$_new_branch"
printf "  Worktree:  %s\n" "$wt_dir"
[[ -n "${session:-}" ]] && printf "  tmux:      %s:%s\n" "$session" "$_new_branch"

log "new: workspace $_new_branch at $wt_dir"
