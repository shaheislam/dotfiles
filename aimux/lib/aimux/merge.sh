#!/usr/bin/env bash
# aimux merge - merge workspace back to main branch

_merge_workspace=""
_merge_pr=false
_merge_squash=false
_merge_message=""
_merge_delete=true
_merge_dry_run=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --pr)
        _merge_pr=true
        shift
        ;;
    --squash)
        _merge_squash=true
        shift
        ;;
    --message | --msg)
        _merge_message="$2"
        shift 2
        ;;
    --delete)
        _merge_delete=true
        shift
        ;;
    --no-delete)
        _merge_delete=false
        shift
        ;;
    --dry-run)
        _merge_dry_run=true
        shift
        ;;
    -h | --help)
        cat <<'HELP'
Usage: aimux merge [options] <workspace>

Merge workspace back to main branch

Options:
  --pr              Create PR instead of local merge
  --squash          Squash commits before merge
  --message MSG     Custom commit message (auto-generated if omitted)
  --delete          Delete workspace after merge (default)
  --no-delete       Keep workspace after merge
  --dry-run         Show what would happen without doing it
  -h, --help        Show this help

Examples:
  aimux merge feature-auth             Merge feature-auth into main
  aimux merge --squash feature-auth    Squash merge
  aimux merge --pr feature-auth        Create PR instead of local merge
  aimux merge --dry-run feature-auth   Preview merge without executing
HELP
        exit 0
        ;;
    -*) die "Unknown option: $1" ;;
    *)
        _merge_workspace="$1"
        shift
        ;;
    esac
done

[[ -z "$_merge_workspace" ]] && die "Usage: aimux merge <workspace>"
require git

# Protected branches — refuse to merge FROM a protected branch
case "$_merge_workspace" in
main | master | develop | staging | production)
    die "Cannot merge from protected branch: $_merge_workspace"
    ;;
esac

# Resolve repo root
root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"
repo_name="$(basename "$root")"

# Resolve worktree path and branch
if [[ -d "$_merge_workspace" ]]; then
    wt_path="$_merge_workspace"
    branch="$(cd "$wt_path" && git_branch)"
else
    wt_path="$(dirname "$root")/${repo_name}-${_merge_workspace}"
    branch="$_merge_workspace"
fi

instance_name="${repo_name}-${branch//\//-}"

# Validate worktree exists
if [[ ! -d "$wt_path" ]]; then
    die "Worktree not found: $wt_path"
fi

# Validate branch exists
if ! git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    die "Branch not found: $branch"
fi

# Check for merge conflicts against main
main_branch="main"
if ! git show-ref --verify --quiet "refs/heads/main" 2>/dev/null; then
    if git show-ref --verify --quiet "refs/heads/master" 2>/dev/null; then
        main_branch="master"
    else
        die "Neither 'main' nor 'master' branch found"
    fi
fi

# Check for uncommitted changes and auto-commit
uncommitted=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$uncommitted" -gt 0 ]]; then
    info "Found $uncommitted uncommitted files in workspace"

    if $_merge_dry_run; then
        info "[dry-run] Would auto-commit $uncommitted files"
    else
        # Stage all changes
        (cd "$wt_path" && git add -A)

        # Generate auto-commit message from branch name and diff stats
        diff_stat=$(cd "$wt_path" && git diff --cached --stat 2>/dev/null | tail -1 || echo "")
        files_changed=$(echo "$diff_stat" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
        clean_branch="$(echo "$branch" | sed 's/[-_]/ /g; s|/| |g')"
        auto_msg="feat: ${clean_branch} - ${files_changed} files changed"

        (cd "$wt_path" && git commit -m "$auto_msg")
        info "Auto-committed: $auto_msg"
    fi
fi

# Check if branch has any changes vs main
commits_ahead=$(git rev-list --count "$main_branch..$branch" 2>/dev/null || echo "0")
if [[ "$commits_ahead" -eq 0 ]]; then
    die "Branch '$branch' has no commits ahead of '$main_branch' — nothing to merge"
fi

# Check for conflicts (dry merge)
if ! git merge-tree "$(git merge-base "$main_branch" "$branch")" "$main_branch" "$branch" 2>/dev/null | grep -qE '^<<<<<<<'; then
    : # No conflicts detected
else
    die "Merge conflicts detected between '$branch' and '$main_branch'. Resolve manually."
fi

# Show diff stats
diff_summary=$(git diff --stat "$main_branch..$branch" 2>/dev/null || echo "no changes")
printf "\n${BOLD}Merge summary${RESET}\n"
printf "  Branch:   %s -> %s\n" "$branch" "$main_branch"
printf "  Commits:  %s ahead\n" "$commits_ahead"
printf "  Changes:\n"
echo "$diff_summary" | sed 's/^/    /'
printf "\n"

if $_merge_dry_run; then
    info "[dry-run] Would merge '$branch' into '$main_branch'"
    $_merge_squash && info "[dry-run] With squash"
    $_merge_delete && info "[dry-run] Would delete workspace after merge"
    $_merge_pr && info "[dry-run] Would create PR instead of local merge"
    exit 0
fi

# Determine merge message
if [[ -z "$_merge_message" ]]; then
    # Try to get prompt from state file
    prompt="$(state_read "$instance_name" "prompt" "")"
    ticket="$(state_read "$instance_name" "ticket" "")"
    if [[ -n "$ticket" && -n "$prompt" ]]; then
        _merge_message="feat: ${ticket} - ${prompt}"
    elif [[ -n "$ticket" ]]; then
        _merge_message="feat: ${ticket}"
    else
        clean_branch="$(echo "$branch" | sed 's/[-_]/ /g; s|/| |g')"
        _merge_message="feat: ${clean_branch}"
    fi
fi

# --- PR workflow ---
if $_merge_pr; then
    require gh

    info "Pushing branch to origin..."
    git push -u origin "$branch" 2>/dev/null || die "Failed to push branch"

    gh_args=(pr create --base "$main_branch" --head "$branch" --title "$_merge_message" --body "")
    info "Creating PR via gh..."
    pr_url=$(gh "${gh_args[@]}" 2>&1) || die "Failed to create PR: $pr_url"

    printf "${GREEN}PR created${RESET}: %s\n" "$pr_url"
    log "merge: PR created for $branch -> $main_branch ($pr_url)"

    if $_merge_delete; then
        info "Deleting workspace (branch kept on remote)..."
        # Source kill.sh logic inline to clean up
        witness_stop "$instance_name" 2>/dev/null || true
        state_remove "$instance_name"
        rm -f "$AIMUX_LOG_DIR/${instance_name}.log" 2>/dev/null || true

        if in_tmux; then
            session="$(tmux_session)"
            tmux_win=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
                grep ":${branch}$" | head -1 | cut -d: -f1 || true)
            [[ -n "$tmux_win" ]] && tmux kill-window -t "$session:$tmux_win" 2>/dev/null || true
        fi

        if [[ -d "$wt_path" ]]; then
            git worktree remove "$wt_path" --force 2>/dev/null || rm -rf "$wt_path"
        fi
        git worktree prune 2>/dev/null || true
        printf "${GREEN}Workspace cleaned up${RESET}\n"
    fi

    exit 0
fi

# --- Local merge workflow ---
info "Merging '$branch' into '$main_branch'..."

# Switch to main worktree for merge
main_wt="$root"

merge_args=()
$_merge_squash && merge_args+=(--squash)
merge_args+=(--no-ff -m "$_merge_message")

(cd "$main_wt" && git checkout "$main_branch" 2>/dev/null) || die "Failed to checkout $main_branch"
(cd "$main_wt" && git merge "$branch" "${merge_args[@]}") || die "Merge failed — resolve conflicts manually"

# If squash, commit the squashed changes
if $_merge_squash; then
    (cd "$main_wt" && git commit -m "$_merge_message" 2>/dev/null) || true
fi

printf "${GREEN}Merged${RESET}: %s -> %s\n" "$branch" "$main_branch"
log "merge: merged $branch -> $main_branch"

# Clean up workspace
if $_merge_delete; then
    info "Cleaning up workspace..."

    # Stop witness
    witness_stop "$instance_name" 2>/dev/null || true

    # Remove state file
    state_remove "$instance_name"

    # Remove log file
    rm -f "$AIMUX_LOG_DIR/${instance_name}.log" 2>/dev/null || true

    # Kill tmux window
    if in_tmux; then
        session="$(tmux_session)"
        tmux_win=$(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null |
            grep ":${branch}$" | head -1 | cut -d: -f1 || true)
        [[ -n "$tmux_win" ]] && tmux kill-window -t "$session:$tmux_win" 2>/dev/null || true
    fi

    # Remove worktree
    if [[ -d "$wt_path" ]]; then
        git worktree remove "$wt_path" --force 2>/dev/null || rm -rf "$wt_path"
    fi

    # Delete branch
    git branch -D "$branch" 2>/dev/null || true

    git worktree prune 2>/dev/null || true

    printf "${GREEN}Workspace cleaned up${RESET}: %s\n" "$branch"
    log "merge: workspace $branch cleaned up"
fi
