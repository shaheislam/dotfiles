#!/usr/bin/env bash
# aimux kill - kill workspace + cleanup worktree

_kill_target=""
_kill_force=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --force | -f)
        _kill_force=true
        shift
        ;;
    -h | --help)
        echo "Usage: aimux kill [--force] <branch-or-path>"
        exit 0
        ;;
    -*) die "Unknown option: $1" ;;
    *)
        _kill_target="$1"
        shift
        ;;
    esac
done

[[ -z "$_kill_target" ]] && die "Usage: aimux kill <branch-or-path>"
require git

# Protected branches
case "$_kill_target" in
main | master | develop | staging | production)
    die "Cannot kill protected branch: $_kill_target"
    ;;
esac

root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"
repo_name="$(basename "$root")"

# Resolve worktree path and branch
if [[ -d "$_kill_target" ]]; then
    wt_path="$_kill_target"
    branch="$(cd "$wt_path" && git_branch)"
else
    wt_path="$(dirname "$root")/${repo_name}-${_kill_target}"
    branch="$_kill_target"
fi

instance_name="${repo_name}-${branch//\//-}"

# Check for uncommitted changes
if [[ -d "$wt_path" ]]; then
    uncommitted=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$uncommitted" -gt 0 ]] && ! $_kill_force; then
        die "Worktree has $uncommitted uncommitted files. Use --force to override."
    fi
fi

# Stop devcontainer
if has docker; then
    container=$(docker ps -q --filter "name=$instance_name" 2>/dev/null || true)
    if [[ -n "$container" ]]; then
        info "Stopping container: $instance_name"
        docker stop "$container" &>/dev/null || true
    fi
fi

# Remove devcontainer instance/workspace dirs
for dir in "$HOME/.devcontainer/instances/$instance_name" \
    "$HOME/.devcontainer/workspaces/$instance_name"; do
    if [[ -d "$dir" ]]; then
        info "Removing: $dir"
        rm -rf "$dir"
    fi
done

# Kill tmux window
if in_tmux; then
    session="$(tmux_session)"
    tmux_win=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
        grep ":${branch}$" | head -1 | cut -d: -f1 || true)
    if [[ -n "$tmux_win" ]]; then
        info "Killing tmux window: $session:$tmux_win"
        tmux kill-window -t "$session:$tmux_win" 2>/dev/null || true
    fi
fi

# Remove worktree
if [[ -d "$wt_path" ]]; then
    info "Removing worktree: $wt_path"
    git worktree remove "$wt_path" --force 2>/dev/null || rm -rf "$wt_path"
fi

# Delete branch
if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    info "Deleting branch: $branch"
    git branch -D "$branch" 2>/dev/null || true
fi

git worktree prune 2>/dev/null || true

# Stop witness process
witness_stop "$instance_name" 2>/dev/null || true

# Remove state file
state_remove "$instance_name"

# Clean up log file
rm -f "$AIMUX_LOG_DIR/${instance_name}.log" 2>/dev/null || true

printf "${GREEN}Workspace killed${RESET}: %s\n" "$_kill_target"
log "kill: removed workspace $_kill_target"
