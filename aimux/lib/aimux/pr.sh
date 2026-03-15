#!/usr/bin/env bash
# aimux pr - create GitHub PR from workspace

_pr_workspace=""
_pr_title=""
_pr_body=""
_pr_draft=false
_pr_base=""
_pr_reviewers=()
_pr_labels=()
_pr_delete=false
_pr_open=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --title | -t)
        _pr_title="$2"
        shift 2
        ;;
    --body | -b)
        _pr_body="$2"
        shift 2
        ;;
    --draft | -d)
        _pr_draft=true
        shift
        ;;
    --base)
        _pr_base="$2"
        shift 2
        ;;
    --reviewer | -r)
        _pr_reviewers+=("$2")
        shift 2
        ;;
    --label | -l)
        _pr_labels+=("$2")
        shift 2
        ;;
    --delete)
        _pr_delete=true
        shift
        ;;
    --open | -o)
        _pr_open=true
        shift
        ;;
    -h | --help)
        cat <<'HELP'
Usage: aimux pr [options] [workspace]

Create GitHub PR from workspace

Options:
  -t, --title TITLE     PR title (default: auto from branch/ticket)
  -b, --body BODY       PR body (default: auto from commits)
  -d, --draft           Create as draft PR
  --base BRANCH         Base branch (default: main)
  -r, --reviewer USER   Add reviewer (repeatable)
  -l, --label LABEL     Add label (repeatable)
  --delete              Delete workspace after PR creation
  -o, --open            Open PR in browser after creation
  -h, --help            Show this help

Examples:
  aimux pr feature-auth               Create PR for feature-auth workspace
  aimux pr --draft --reviewer alice    Draft PR with reviewer
  aimux pr --title "Fix auth" --open   Custom title, open in browser
  aimux pr                             Auto-detect workspace from cwd
HELP
        exit 0
        ;;
    -*) die "Unknown option: $1" ;;
    *)
        _pr_workspace="$1"
        shift
        ;;
    esac
done

# Require gh CLI
if ! has gh; then
    die "GitHub CLI (gh) is required for 'aimux pr'. Install: brew install gh"
fi

# Check gh auth
if ! gh auth status &>/dev/null; then
    die "Not authenticated with GitHub CLI. Run: gh auth login"
fi

require git

# Resolve repo root
root="$(git_root)"
[[ -z "$root" ]] && die "Not in a git repository"
repo_name="$(basename "$root")"

# Auto-detect workspace from cwd or fzf
if [[ -z "$_pr_workspace" ]]; then
    # Try to detect from current directory
    current_branch="$(git_branch)"
    if [[ -n "$current_branch" && "$current_branch" != "main" && "$current_branch" != "master" ]]; then
        _pr_workspace="$current_branch"
        info "Auto-detected workspace from current branch: $_pr_workspace"
    elif has fzf && [[ -d "$AIMUX_STATE_DIR" ]]; then
        # fzf picker from state files
        _selection=$(ls "$AIMUX_STATE_DIR"/*.json 2>/dev/null |
            xargs -I{} basename {} .json |
            fzf --prompt="Select workspace: " --height=40% --reverse || true)
        [[ -z "$_selection" ]] && die "No workspace selected"
        _pr_workspace="$(state_read "$_selection" "branch" "$_selection")"
        info "Selected workspace: $_pr_workspace"
    else
        die "Usage: aimux pr <workspace> (or run from within a workspace branch)"
    fi
fi

# Resolve worktree path and branch
if [[ -d "$_pr_workspace" ]]; then
    wt_path="$_pr_workspace"
    branch="$(cd "$wt_path" && git_branch)"
else
    wt_path="$(dirname "$root")/${repo_name}-${_pr_workspace}"
    branch="$_pr_workspace"
fi

instance_name="${repo_name}-${branch//\//-}"

# Validate branch exists
if ! git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    die "Branch not found: $branch"
fi

# Determine base branch
if [[ -z "$_pr_base" ]]; then
    if git show-ref --verify --quiet "refs/heads/main" 2>/dev/null; then
        _pr_base="main"
    elif git show-ref --verify --quiet "refs/heads/master" 2>/dev/null; then
        _pr_base="master"
    else
        die "Cannot determine base branch. Use --base to specify."
    fi
fi

# Check if branch has commits ahead of base
commits_ahead=$(git rev-list --count "$_pr_base..$branch" 2>/dev/null || echo "0")
if [[ "$commits_ahead" -eq 0 ]]; then
    die "Branch '$branch' has no commits ahead of '$_pr_base' — nothing to PR"
fi

# Auto-commit any uncommitted changes
if [[ -d "$wt_path" ]]; then
    uncommitted=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$uncommitted" -gt 0 ]]; then
        info "Auto-committing $uncommitted uncommitted files..."
        (cd "$wt_path" && git add -A)

        diff_stat=$(cd "$wt_path" && git diff --cached --stat 2>/dev/null | tail -1 || echo "")
        files_changed=$(echo "$diff_stat" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
        clean_branch="$(echo "$branch" | sed 's/[-_]/ /g; s|/| |g')"
        auto_msg="feat: ${clean_branch} - ${files_changed} files changed"

        (cd "$wt_path" && git commit -m "$auto_msg")
        info "Auto-committed: $auto_msg"
    fi
fi

# Auto-generate title if not provided
if [[ -z "$_pr_title" ]]; then
    # Try state file for ticket info
    ticket="$(state_read "$instance_name" "ticket" "")"
    prompt="$(state_read "$instance_name" "prompt" "")"

    if [[ -n "$ticket" && -n "$prompt" ]]; then
        _pr_title="${ticket}: ${prompt}"
    elif [[ -n "$ticket" ]]; then
        _pr_title="$ticket"
    else
        # Convert branch name to title
        _pr_title="$(echo "$branch" | sed 's/[-_]/ /g; s|/| |g; s/\b\(.\)/\U\1/')"
    fi
fi

# Auto-generate body if not provided
if [[ -z "$_pr_body" ]]; then
    # Build body from commit log
    _pr_body="$(git log --oneline "$_pr_base..$branch" 2>/dev/null || echo "")"
    if [[ -n "$_pr_body" ]]; then
        _pr_body="## Commits

${_pr_body}

## Stats
$(git diff --stat "$_pr_base..$branch" 2>/dev/null || echo "")"
    fi
fi

# Push branch to origin
info "Pushing branch to origin..."
git push -u origin "$branch" 2>/dev/null || die "Failed to push branch to origin"

# Build gh pr create args
gh_args=(pr create --base "$_pr_base" --head "$branch")
gh_args+=(--title "$_pr_title")
[[ -n "$_pr_body" ]] && gh_args+=(--body "$_pr_body")
$_pr_draft && gh_args+=(--draft)

# Create PR
info "Creating PR: $_pr_title"
pr_url=$(gh "${gh_args[@]}" 2>&1) || die "Failed to create PR: $pr_url"

printf "${GREEN}PR created${RESET}: %s\n" "$pr_url"

# Add reviewers
if [[ ${#_pr_reviewers[@]} -gt 0 ]]; then
    reviewer_list=$(printf "%s," "${_pr_reviewers[@]}")
    reviewer_list="${reviewer_list%,}"
    info "Adding reviewers: $reviewer_list"
    gh pr edit "$branch" --add-reviewer "$reviewer_list" 2>/dev/null || warn "Failed to add reviewers"
fi

# Add labels
if [[ ${#_pr_labels[@]} -gt 0 ]]; then
    label_list=$(printf "%s," "${_pr_labels[@]}")
    label_list="${label_list%,}"
    info "Adding labels: $label_list"
    gh pr edit "$branch" --add-label "$label_list" 2>/dev/null || warn "Failed to add labels"
fi

# Open in browser
if $_pr_open; then
    gh pr view "$branch" --web 2>/dev/null || warn "Failed to open PR in browser"
fi

log "pr: created PR for $branch -> $_pr_base ($pr_url)"

# Delete workspace after PR creation
if $_pr_delete; then
    info "Deleting workspace..."

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

    git worktree prune 2>/dev/null || true

    printf "${GREEN}Workspace cleaned up${RESET}: %s\n" "$branch"
    log "pr: workspace $branch cleaned up"
fi
