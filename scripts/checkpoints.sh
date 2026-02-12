#!/usr/bin/env bash
#
# checkpoints.sh - Session context linked to git commits
#
# Captures Claude Code session transcript slices and stores them
# as structured metadata linked to commit SHAs on a checkpoints/v1
# orphan branch. Answers "why was this commit made?" not just "what changed?"
#
# Usage:
#   checkpoints.sh enable [--strategy manual|auto]   # Install hooks
#   checkpoints.sh disable [--purge]                   # Disable (--purge also removes shared git hooks)
#   checkpoints.sh status                             # Current session state
#   checkpoints.sh log [--branch <name>]              # List checkpoints
#   checkpoints.sh show <commit-sha>                  # Show checkpoint for commit
#   checkpoints.sh resume [branch]                    # Show latest checkpoint context for branch
#   checkpoints.sh context [--commits N]              # Condensed context for session priming
#   checkpoints.sh search <query>                     # Search checkpoints
#   checkpoints.sh rewind                             # Interactive checkpoint browser (fzf)
#   checkpoints.sh clean                              # Remove orphaned checkpoint data
#   checkpoints.sh reset [--force]                    # Delete checkpoint branch
#   checkpoints.sh doctor                             # Validate hooks installed
#
# Exit codes:
#   0 - Success
#   1 - Error
#   2 - Not in a git repo / not enabled

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Constants
CHECKPOINT_BRANCH="checkpoints/v1"
PENDING_DIR=".checkpoints"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="${SCRIPT_DIR}/hooks"

# --- Helpers ---

print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_error()   { echo -e "${RED}✗${NC} $*" >&2; }
print_warn()    { echo -e "${YELLOW}!${NC} $*"; }
print_info()    { echo -e "${BLUE}→${NC} $*"; }

require_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 2
    fi
}

# Find the git toplevel (works in worktrees too)
git_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Find the real .git dir (resolves worktree .git files)
git_dir() {
    git rev-parse --git-common-dir 2>/dev/null
}

# Get active Claude session JSONL for current project
find_active_session() {
    local project_dir
    # Claude stores sessions under ~/.claude/projects/<hash>/
    # Find the most recently modified .jsonl file
    project_dir=$(find_project_dir)
    if [[ -z "$project_dir" || ! -d "$project_dir" ]]; then
        return 1
    fi
    # Most recently modified JSONL = active session
    find "$project_dir" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null \
        | head -1
}

# Find Claude project directory for current git repo
find_project_dir() {
    local claude_projects="${HOME}/.claude/projects"
    local repo_path
    repo_path=$(git_root)
    if [[ -z "$repo_path" ]]; then
        return 1
    fi
    # Claude hashes the project path for the directory name
    # Convention: replace / with - and prepend -
    local hash_name="-$(echo "$repo_path" | sed 's|^/||; s|/|-|g')"
    local project_path="${claude_projects}/${hash_name}"
    if [[ -d "$project_path" ]]; then
        echo "$project_path"
    fi
}

# Extract session ID from JSONL path
session_id_from_path() {
    basename "$1" .jsonl
}

# --- Commands ---

cmd_enable() {
    require_git_repo
    local strategy="manual"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --strategy) strategy="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local root
    root=$(git_root)
    # Git hooks must go in the common dir (shared across worktrees)
    local git_hooks_dir
    git_hooks_dir="$(git rev-parse --git-common-dir)/hooks"

    mkdir -p "$git_hooks_dir"
    mkdir -p "${root}/${PENDING_DIR}"

    # Create .gitignore entry for .checkpoints/ if not already present
    if [[ -f "${root}/.gitignore" ]]; then
        if ! grep -q "^\.checkpoints/" "${root}/.gitignore" 2>/dev/null; then
            echo -e "\n# Checkpoint pending data (ephemeral)\n.checkpoints/" >> "${root}/.gitignore"
            print_info "Added .checkpoints/ to .gitignore"
        fi
    else
        echo -e "# Checkpoint pending data (ephemeral)\n.checkpoints/" > "${root}/.gitignore"
        print_info "Created .gitignore with .checkpoints/"
    fi

    # Create orphan branch if it doesn't exist
    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_info "Creating orphan branch: ${CHECKPOINT_BRANCH}"
        # Create orphan branch without disturbing working tree
        local tree_sha
        tree_sha=$(git hash-object -t tree /dev/null)
        local commit_sha
        commit_sha=$(echo "Initialize checkpoint storage" | git commit-tree "$tree_sha")
        git update-ref "refs/heads/${CHECKPOINT_BRANCH}" "$commit_sha"
        print_success "Orphan branch created"
    fi

    # Install git hooks (chainable — append if hook already exists)
    install_git_hook "prepare-commit-msg" "${HOOKS_DIR}/checkpoint-commit-msg.sh" "$git_hooks_dir"
    install_git_hook "post-commit" "${HOOKS_DIR}/checkpoint-post-commit.sh" "$git_hooks_dir"
    install_git_hook "pre-push" "${HOOKS_DIR}/checkpoint-pre-push.sh" "$git_hooks_dir"

    # Write config
    local config_file="${root}/${PENDING_DIR}/config.json"
    cat > "$config_file" <<EOF
{
  "enabled": true,
  "strategy": "${strategy}",
  "branch": "${CHECKPOINT_BRANCH}",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    print_success "Checkpoints enabled (strategy: ${strategy})"
    print_info "Git hooks installed in ${git_hooks_dir}"
    print_info "Claude Code hooks must be registered separately via settings.json"
}

install_git_hook() {
    local hook_name="$1"
    local source_script="$2"
    local hooks_dir="$3"
    local hook_path="${hooks_dir}/${hook_name}"
    local marker="# --- checkpoints ---"

    if [[ ! -f "$source_script" ]]; then
        print_error "Hook source not found: ${source_script}"
        return 1
    fi

    if [[ -f "$hook_path" ]]; then
        # Check if already installed
        if grep -q "$marker" "$hook_path" 2>/dev/null; then
            print_info "${hook_name}: already installed"
            return 0
        fi
        # Append to existing hook
        {
            echo ""
            echo "$marker"
            echo "bash \"${source_script}\" \"\$@\""
            echo "# --- end checkpoints ---"
        } >> "$hook_path"
    else
        # Create new hook
        {
            echo "#!/usr/bin/env bash"
            echo "$marker"
            echo "bash \"${source_script}\" \"\$@\""
            echo "# --- end checkpoints ---"
        } > "$hook_path"
        chmod +x "$hook_path"
    fi
    print_success "${hook_name}: installed"
}

cmd_disable() {
    require_git_repo
    local root
    root=$(git_root)
    local purge=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge) purge=true; shift ;;
            *) shift ;;
        esac
    done

    # Remove local config (this alone disables — hooks are no-ops without config)
    if [[ -d "${root}/${PENDING_DIR}" ]]; then
        rm -rf "${root}/${PENDING_DIR}"
        print_success "Pending directory removed"
    fi

    # Only remove shared hooks with --purge (safe for standalone repos,
    # dangerous in worktree setups where other worktrees may still be enabled)
    if $purge; then
        local git_hooks_dir
        git_hooks_dir="$(git rev-parse --git-common-dir)/hooks"
        local marker="# --- checkpoints ---"
        local end_marker="# --- end checkpoints ---"
        for hook_name in prepare-commit-msg post-commit pre-push; do
            local hook_path="${git_hooks_dir}/${hook_name}"
            if [[ -f "$hook_path" ]] && grep -q "$marker" "$hook_path" 2>/dev/null; then
                sed -i '' "/${marker}/,/${end_marker}/d" "$hook_path"
                local line_count
                line_count=$(wc -l < "$hook_path" | tr -d ' ')
                if [[ "$line_count" -le 1 ]]; then
                    rm "$hook_path"
                fi
                print_success "${hook_name}: removed"
            fi
        done
    fi

    print_success "Checkpoints disabled"
}

cmd_status() {
    require_git_repo
    local root
    root=$(git_root)

    echo -e "${BOLD}Checkpoint Status${NC}"
    echo "─────────────────────────────"

    # Config
    local config_file="${root}/${PENDING_DIR}/config.json"
    if [[ -f "$config_file" ]]; then
        local strategy
        strategy=$(jq -r '.strategy' "$config_file" 2>/dev/null || echo "unknown")
        print_success "Enabled (strategy: ${strategy})"
    else
        print_error "Not enabled in this repo"
        echo "  Run: checkpoints enable"
        return 0
    fi

    # Orphan branch
    if git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        local count
        count=$(git rev-list --count "${CHECKPOINT_BRANCH}" 2>/dev/null || echo 0)
        print_success "Branch ${CHECKPOINT_BRANCH}: ${count} commits"
    else
        print_warn "Branch ${CHECKPOINT_BRANCH}: not created"
    fi

    # Pending checkpoints
    local pending_count=0
    if [[ -d "${root}/${PENDING_DIR}" ]]; then
        pending_count=$(find "${root}/${PENDING_DIR}" -name 'pending.json' 2>/dev/null | wc -l | tr -d ' ')
    fi
    print_info "Pending checkpoints: ${pending_count}"

    # Active session
    local session_file
    session_file=$(find_active_session 2>/dev/null || true)
    if [[ -n "$session_file" ]]; then
        local sid
        sid=$(session_id_from_path "$session_file")
        local lines
        lines=$(wc -l < "$session_file" | tr -d ' ')
        print_success "Active session: ${sid:0:12}... (${lines} lines)"
    else
        print_warn "No active Claude session detected"
    fi

    # Git hooks
    echo ""
    echo -e "${BOLD}Git Hooks${NC}"
    local hooks_dir
    hooks_dir="$(git rev-parse --git-common-dir)/hooks"
    for hook_name in prepare-commit-msg post-commit pre-push; do
        if [[ -f "${hooks_dir}/${hook_name}" ]] && grep -q "checkpoints" "${hooks_dir}/${hook_name}" 2>/dev/null; then
            print_success "${hook_name}"
        else
            print_error "${hook_name}: not installed"
        fi
    done
}

cmd_log() {
    require_git_repo
    local branch_filter=""
    local git_mode=false
    local limit_n=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch) branch_filter="$2"; shift 2 ;;
            --git) git_mode=true; shift ;;
            -n) limit_n="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_error "No checkpoint branch found. Run: checkpoints enable"
        exit 2
    fi

    # Git mode: annotated git log with checkpoint markers
    if $git_mode; then
        cmd_log_git "$branch_filter" "$limit_n"
        return
    fi

    # List checkpoint metadata files from orphan branch
    local files
    files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null | grep 'metadata.json$' || true)

    if [[ -z "$files" ]]; then
        print_info "No checkpoints recorded yet"
        return 0
    fi

    echo -e "${BOLD}Checkpoint Log${NC}"
    echo "─────────────────────────────────────────────────────────────"
    printf "%-14s %-20s %-12s %s\n" "COMMIT" "TIMESTAMP" "TOKENS" "SUMMARY"
    echo "─────────────────────────────────────────────────────────────"

    while IFS= read -r meta_path; do
        local content
        content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || continue)
        local commit_sha timestamp tokens summary branch_name
        commit_sha=$(echo "$content" | jq -r '.commit_sha // "unknown"' 2>/dev/null)
        timestamp=$(echo "$content" | jq -r '.timestamp // "unknown"' 2>/dev/null)
        tokens=$(echo "$content" | jq -r '.token_estimate // 0' 2>/dev/null)
        summary=$(echo "$content" | jq -r '.summary // "no summary"' 2>/dev/null | head -c 40)
        branch_name=$(echo "$content" | jq -r '.branch // ""' 2>/dev/null)

        # Filter by branch if requested
        if [[ -n "$branch_filter" && "$branch_name" != "$branch_filter" ]]; then
            continue
        fi

        printf "%-14s %-20s %-12s %s\n" \
            "${commit_sha:0:12}" \
            "${timestamp}" \
            "${tokens}" \
            "${summary}"
    done <<< "$files"
}

# Annotated git log with checkpoint markers
cmd_log_git() {
    local branch_filter="$1"
    local limit_n="$2"

    # Build associative array of checkpoint data keyed by full SHA
    declare -A ckpt_data
    local meta_files
    meta_files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null | grep 'metadata.json$' || true)

    if [[ -n "$meta_files" ]]; then
        while IFS= read -r meta_path; do
            local content
            content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || true)
            [[ -z "$content" ]] && continue

            local sha tokens tools summary ckpt_branch
            sha=$(echo "$content" | jq -r '.commit_sha // ""' 2>/dev/null)
            ckpt_branch=$(echo "$content" | jq -r '.branch // ""' 2>/dev/null)
            [[ -z "$sha" ]] && continue

            # Filter by branch if requested
            if [[ -n "$branch_filter" && "$ckpt_branch" != "$branch_filter" ]]; then
                continue
            fi

            tokens=$(echo "$content" | jq -r '.token_estimate // 0' 2>/dev/null)
            tools=$(echo "$content" | jq -r '(.tool_calls_summary // []) | map(. | ltrimstr(" ")) | join(", ")' 2>/dev/null)
            summary=$(echo "$content" | jq -r '.summary // ""' 2>/dev/null | head -c 40)

            ckpt_data["$sha"]="${tokens}|${tools}|${summary}"
        done <<< "$meta_files"
    fi

    # Walk git log
    local git_log_args=("--format=%H %s")
    if [[ -n "$limit_n" ]]; then
        git_log_args+=("-n" "$limit_n")
    fi

    while IFS= read -r line; do
        local full_sha msg
        full_sha="${line%% *}"
        msg="${line#* }"
        local short_sha="${full_sha:0:7}"

        echo -e "${CYAN}${short_sha}${NC} ${msg}"

        if [[ -n "${ckpt_data[$full_sha]:-}" ]]; then
            local entry="${ckpt_data[$full_sha]}"
            local tokens tools summary
            tokens="${entry%%|*}"
            entry="${entry#*|}"
            tools="${entry%%|*}"
            summary="${entry#*|}"

            local annotation="✦ ${tokens} tokens"
            if [[ -n "$tools" ]]; then
                annotation+=" │ ${tools}"
            fi
            if [[ -n "$summary" ]]; then
                annotation+=" │ ${summary}"
            fi
            echo -e "        ${YELLOW}╰─${NC} ${annotation}"
        fi
    done < <(git log "${git_log_args[@]}")
}

cmd_show() {
    require_git_repo
    local commit_sha="${1:-}"

    if [[ -z "$commit_sha" ]]; then
        print_error "Usage: checkpoints show <commit-sha>"
        exit 1
    fi

    # Resolve short SHA to full
    local full_sha
    full_sha=$(git rev-parse "$commit_sha" 2>/dev/null || true)
    if [[ -z "$full_sha" ]]; then
        print_error "Unknown commit: ${commit_sha}"
        exit 1
    fi

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_error "No checkpoint branch found"
        exit 2
    fi

    # Look up sharded path
    local shard="${full_sha:0:2}/${full_sha:2:6}"
    local meta_path="${shard}/metadata.json"

    local content
    content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || true)
    if [[ -z "$content" ]]; then
        print_error "No checkpoint found for commit ${commit_sha}"
        exit 1
    fi

    echo -e "${BOLD}Checkpoint: ${commit_sha}${NC}"
    echo "═══════════════════════════════════════════════════"

    # Show metadata
    echo -e "\n${CYAN}Metadata${NC}"
    echo "$content" | jq '.' 2>/dev/null

    # Show transcript if available
    local sessions_dir="${shard}/sessions"
    local session_files
    session_files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" -- "${sessions_dir}" 2>/dev/null || true)

    if [[ -n "$session_files" ]]; then
        echo -e "\n${CYAN}Session Transcripts${NC}"
        while IFS= read -r sf; do
            case "$sf" in
                */prompt.txt)
                    echo -e "\n${YELLOW}── User Prompts ──${NC}"
                    git show "${CHECKPOINT_BRANCH}:${sf}" 2>/dev/null
                    ;;
                */transcript.jsonl)
                    echo -e "\n${YELLOW}── Transcript ($(git show "${CHECKPOINT_BRANCH}:${sf}" 2>/dev/null | wc -l | tr -d ' ') lines) ──${NC}"
                    git show "${CHECKPOINT_BRANCH}:${sf}" 2>/dev/null | head -20
                    local total
                    total=$(git show "${CHECKPOINT_BRANCH}:${sf}" 2>/dev/null | wc -l | tr -d ' ')
                    if [[ "$total" -gt 20 ]]; then
                        echo -e "${BLUE}  ... (${total} lines total, showing first 20)${NC}"
                    fi
                    ;;
            esac
        done <<< "$session_files"
    fi
}

cmd_rewind() {
    require_git_repo

    if ! command -v fzf &>/dev/null; then
        print_error "fzf is required for interactive rewind"
        exit 1
    fi

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_error "No checkpoint branch found"
        exit 2
    fi

    # Build checkpoint list for fzf
    local files
    files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null | grep 'metadata.json$' || true)

    if [[ -z "$files" ]]; then
        print_info "No checkpoints to browse"
        return 0
    fi

    local entries=""
    while IFS= read -r meta_path; do
        local content
        content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || continue)
        local commit_sha timestamp summary branch_name
        commit_sha=$(echo "$content" | jq -r '.commit_sha // "unknown"' 2>/dev/null)
        timestamp=$(echo "$content" | jq -r '.timestamp // "unknown"' 2>/dev/null)
        summary=$(echo "$content" | jq -r '.summary // "no summary"' 2>/dev/null | head -c 50)
        branch_name=$(echo "$content" | jq -r '.branch // ""' 2>/dev/null)
        entries+="${commit_sha:0:12}  ${timestamp}  [${branch_name}]  ${summary}\n"
    done <<< "$files"

    local selected
    selected=$(echo -e "$entries" | fzf --header="Select checkpoint to view" --preview="echo {} | awk '{print \$1}' | xargs bash ${SCRIPT_DIR}/checkpoints.sh show" || true)

    if [[ -n "$selected" ]]; then
        local selected_sha
        selected_sha=$(echo "$selected" | awk '{print $1}')
        cmd_show "$selected_sha"
    fi
}

cmd_resume() {
    require_git_repo
    local target_branch="${1:-}"

    if [[ -z "$target_branch" ]]; then
        target_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    fi

    if [[ -z "$target_branch" ]]; then
        print_error "Could not determine current branch"
        exit 1
    fi

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_error "No checkpoint branch found. Run: checkpoints enable"
        exit 2
    fi

    # Find the latest checkpoint for this branch
    local files
    files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null | grep 'metadata.json$' || true)

    if [[ -z "$files" ]]; then
        print_info "No checkpoints recorded yet"
        return 0
    fi

    local latest_sha="" latest_timestamp="" latest_meta=""
    while IFS= read -r meta_path; do
        local content
        content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || continue)
        local branch_name timestamp
        branch_name=$(echo "$content" | jq -r '.branch // ""' 2>/dev/null)
        timestamp=$(echo "$content" | jq -r '.timestamp // ""' 2>/dev/null)

        if [[ "$branch_name" == "$target_branch" ]]; then
            if [[ -z "$latest_timestamp" || "$timestamp" > "$latest_timestamp" ]]; then
                latest_timestamp="$timestamp"
                latest_meta="$content"
                latest_sha=$(echo "$content" | jq -r '.commit_sha // ""' 2>/dev/null)
            fi
        fi
    done <<< "$files"

    if [[ -z "$latest_meta" ]]; then
        print_info "No checkpoints found for branch: ${target_branch}"
        return 0
    fi

    # Extract checkpoint data
    local summary files_modified new_files tool_calls token_estimate
    summary=$(echo "$latest_meta" | jq -r '.summary // "no summary"' 2>/dev/null)
    files_modified=$(echo "$latest_meta" | jq -r '.files_modified // [] | .[]' 2>/dev/null)
    new_files=$(echo "$latest_meta" | jq -r '.new_files // [] | .[]' 2>/dev/null)
    tool_calls=$(echo "$latest_meta" | jq -r '.tool_calls_summary // [] | .[]' 2>/dev/null)
    token_estimate=$(echo "$latest_meta" | jq -r '.token_estimate // 0' 2>/dev/null)

    # Get the commit message and diff stat
    local commit_msg="" diff_stat=""
    if git rev-parse "$latest_sha" >/dev/null 2>&1; then
        commit_msg=$(git log -1 --format=%s "$latest_sha" 2>/dev/null || true)
        diff_stat=$(git diff --stat "${latest_sha}^..${latest_sha}" 2>/dev/null || true)
    fi

    # Get stored prompt
    local shard="${latest_sha:0:2}/${latest_sha:2:6}"
    local prompt_content=""
    local session_files
    session_files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" -- "${shard}/sessions" 2>/dev/null || true)
    if [[ -n "$session_files" ]]; then
        while IFS= read -r sf; do
            case "$sf" in
                */prompt.txt)
                    prompt_content=$(git show "${CHECKPOINT_BRANCH}:${sf}" 2>/dev/null | head -10)
                    break
                    ;;
            esac
        done <<< "$session_files"
    fi

    # Output formatted resume context
    echo -e "${BOLD}Resume Context: ${target_branch}${NC}"
    echo "═══════════════════════════════════════════════════"
    echo -e "${CYAN}Last checkpoint:${NC} ${latest_sha:0:12} (${latest_timestamp})"
    echo -e "${CYAN}Commit:${NC} ${commit_msg}"
    echo -e "${CYAN}Tokens used:${NC} ~${token_estimate}"
    echo -e "${CYAN}Summary:${NC} ${summary}"

    if [[ -n "$files_modified" ]]; then
        echo -e "\n${YELLOW}Files modified:${NC}"
        echo "$files_modified" | sed 's/^/  /'
    fi
    if [[ -n "$new_files" ]]; then
        echo -e "\n${YELLOW}New files:${NC}"
        echo "$new_files" | sed 's/^/  /'
    fi
    if [[ -n "$tool_calls" ]]; then
        echo -e "\n${YELLOW}Tool calls:${NC}"
        echo "$tool_calls" | sed 's/^/  /'
    fi
    if [[ -n "$prompt_content" ]]; then
        echo -e "\n${YELLOW}Last prompt:${NC}"
        echo "$prompt_content" | sed 's/^/  /'
    fi
    if [[ -n "$diff_stat" ]]; then
        echo -e "\n${YELLOW}Diff stat:${NC}"
        echo "$diff_stat" | sed 's/^/  /'
    fi

    echo ""
    echo -e "${GREEN}To continue where you left off, use this context in your next prompt.${NC}"
}

cmd_context() {
    require_git_repo
    local max_commits=5
    local branch_filter=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --commits) max_commits="$2"; shift 2 ;;
            --branch) branch_filter="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_error "No checkpoint branch found"
        exit 2
    fi

    local files
    files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null | grep 'metadata.json$' || true)

    if [[ -z "$files" ]]; then
        print_info "No checkpoints recorded yet"
        return 0
    fi

    # Collect all checkpoints with timestamps for sorting
    local entries=()
    while IFS= read -r meta_path; do
        local content
        content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || continue)
        local timestamp branch_name
        timestamp=$(echo "$content" | jq -r '.timestamp // "1970-01-01T00:00:00Z"' 2>/dev/null)
        branch_name=$(echo "$content" | jq -r '.branch // ""' 2>/dev/null)

        if [[ -n "$branch_filter" && "$branch_name" != "$branch_filter" ]]; then
            continue
        fi

        entries+=("${timestamp}|${meta_path}")
    done <<< "$files"

    if [[ ${#entries[@]} -eq 0 ]]; then
        print_info "No checkpoints match filter"
        return 0
    fi

    # Sort by timestamp descending
    local sorted
    sorted=$(printf '%s\n' "${entries[@]}" | sort -r | head -n "$max_commits")

    # Output condensed context block
    echo "--- Checkpoint Context (last ${max_commits} commits) ---"
    echo ""
    while IFS= read -r entry; do
        local ts meta_path
        ts="${entry%%|*}"
        meta_path="${entry#*|}"

        local content
        content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || continue)
        local commit_sha summary branch_name files_mod token_est
        commit_sha=$(echo "$content" | jq -r '.commit_sha // "unknown"' 2>/dev/null)
        summary=$(echo "$content" | jq -r '.summary // "no summary"' 2>/dev/null | head -c 100)
        branch_name=$(echo "$content" | jq -r '.branch // ""' 2>/dev/null)
        files_mod=$(echo "$content" | jq -r '.files_modified // [] | join(", ")' 2>/dev/null)
        token_est=$(echo "$content" | jq -r '.token_estimate // 0' 2>/dev/null)

        # Get commit subject
        local commit_msg=""
        if git rev-parse "$commit_sha" >/dev/null 2>&1; then
            commit_msg=$(git log -1 --format=%s "$commit_sha" 2>/dev/null || true)
        fi

        echo "- ${commit_sha:0:8} [${branch_name}] ${ts}"
        echo "  Commit: ${commit_msg:-unknown}"
        echo "  Why: ${summary}"
        if [[ -n "$files_mod" ]]; then
            echo "  Files: ${files_mod}"
        fi
        echo ""
    done <<< "$sorted"
    echo "--- End Context ---"
}

cmd_search() {
    require_git_repo
    local query="${1:-}"

    if [[ -z "$query" ]]; then
        print_error "Usage: checkpoints search <query>"
        exit 1
    fi

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_error "No checkpoint branch found"
        exit 2
    fi

    echo -e "${BOLD}Searching checkpoints for: ${query}${NC}"
    echo "─────────────────────────────────────────────────────────────"

    local found=0

    # Search metadata files
    local meta_files
    meta_files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null | grep 'metadata.json$' || true)

    if [[ -n "$meta_files" ]]; then
        while IFS= read -r meta_path; do
            local content
            content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || continue)

            if echo "$content" | grep -qi "$query" 2>/dev/null; then
                local commit_sha timestamp summary branch_name
                commit_sha=$(echo "$content" | jq -r '.commit_sha // "unknown"' 2>/dev/null)
                timestamp=$(echo "$content" | jq -r '.timestamp // "unknown"' 2>/dev/null)
                summary=$(echo "$content" | jq -r '.summary // "no summary"' 2>/dev/null | head -c 60)
                branch_name=$(echo "$content" | jq -r '.branch // ""' 2>/dev/null)
                echo -e "  ${GREEN}metadata${NC} ${commit_sha:0:12} [${branch_name}] ${timestamp}"
                echo -e "    ${summary}"
                found=$((found + 1))
            fi
        done <<< "$meta_files"
    fi

    # Search transcript and prompt files
    local all_files
    all_files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null \
        | grep -E '(transcript\.jsonl|prompt\.txt)$' || true)

    if [[ -n "$all_files" ]]; then
        while IFS= read -r file_path; do
            local file_content
            file_content=$(git show "${CHECKPOINT_BRANCH}:${file_path}" 2>/dev/null || continue)

            if echo "$file_content" | grep -qi "$query" 2>/dev/null; then
                # Extract shard from path to find the commit
                local shard_prefix
                shard_prefix=$(echo "$file_path" | cut -d'/' -f1-2)
                local file_type
                file_type=$(basename "$file_path")

                echo -e "  ${CYAN}${file_type}${NC} at ${shard_prefix}"
                echo "$file_content" | grep -i "$query" 2>/dev/null | head -3 | sed 's/^/    /'
                found=$((found + 1))
            fi
        done <<< "$all_files"
    fi

    echo ""
    if [[ $found -eq 0 ]]; then
        print_info "No matches found"
    else
        print_success "${found} match(es) found"
    fi
}

cmd_clean() {
    require_git_repo

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_info "No checkpoint branch — nothing to clean"
        return 0
    fi

    echo -e "${BOLD}Cleaning orphaned checkpoints...${NC}"

    local files
    files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" 2>/dev/null | grep 'metadata.json$' || true)

    if [[ -z "$files" ]]; then
        print_info "No checkpoints to clean"
        return 0
    fi

    local orphaned=0
    local total=0
    local orphaned_shards=()

    while IFS= read -r meta_path; do
        total=$((total + 1))
        local content
        content=$(git show "${CHECKPOINT_BRANCH}:${meta_path}" 2>/dev/null || continue)
        local commit_sha
        commit_sha=$(echo "$content" | jq -r '.commit_sha // ""' 2>/dev/null)

        if [[ -n "$commit_sha" ]] && ! git rev-parse "$commit_sha" >/dev/null 2>&1; then
            local shard
            shard=$(dirname "$meta_path")
            orphaned_shards+=("$shard")
            orphaned=$((orphaned + 1))
            print_warn "Orphaned: ${commit_sha:0:12} (commit no longer exists)"
        fi
    done <<< "$files"

    if [[ $orphaned -eq 0 ]]; then
        print_success "All ${total} checkpoints are valid"
        return 0
    fi

    print_info "Found ${orphaned} orphaned checkpoint(s) out of ${total}"

    # Rebuild the tree without orphaned entries
    local tmp_index
    tmp_index=$(mktemp)
    export GIT_INDEX_FILE="$tmp_index"
    local cleanup_func
    cleanup_func() { rm -f "$tmp_index"; }
    trap cleanup_func EXIT

    git read-tree "${CHECKPOINT_BRANCH}" 2>/dev/null

    for shard in "${orphaned_shards[@]}"; do
        # Remove all files under this shard
        local shard_files
        shard_files=$(git ls-tree -r --name-only "${CHECKPOINT_BRANCH}" -- "$shard" 2>/dev/null || true)
        if [[ -n "$shard_files" ]]; then
            while IFS= read -r sf; do
                git update-index --force-remove "$sf" 2>/dev/null || true
            done <<< "$shard_files"
        fi
    done

    local new_tree
    new_tree=$(git write-tree)
    local parent_sha
    parent_sha=$(git rev-parse "${CHECKPOINT_BRANCH}")
    local new_commit
    new_commit=$(echo "clean: removed ${orphaned} orphaned checkpoint(s)" | git commit-tree "$new_tree" -p "$parent_sha")
    git update-ref "refs/heads/${CHECKPOINT_BRANCH}" "$new_commit"

    unset GIT_INDEX_FILE
    rm -f "$tmp_index"
    trap - EXIT

    print_success "Removed ${orphaned} orphaned checkpoint(s)"
}

cmd_reset() {
    require_git_repo
    local force=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f) force=true; shift ;;
            *) shift ;;
        esac
    done

    if ! git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_info "No checkpoint branch to reset"
        return 0
    fi

    local count
    count=$(git rev-list --count "${CHECKPOINT_BRANCH}" 2>/dev/null || echo 0)

    if ! $force; then
        print_warn "This will delete the ${CHECKPOINT_BRANCH} branch (${count} commits)"
        print_warn "All checkpoint data will be permanently lost"
        print_error "Use --force to confirm: checkpoints reset --force"
        exit 1
    fi

    git update-ref -d "refs/heads/${CHECKPOINT_BRANCH}"
    print_success "Checkpoint branch deleted (${count} commits removed)"
    print_info "Run 'checkpoints enable' to start fresh"
}

cmd_doctor() {
    require_git_repo
    local root
    root=$(git_root)
    local pass=0 fail=0 warn=0

    echo -e "${BOLD}Checkpoint Doctor${NC}"
    echo "─────────────────────────────"

    # Check dependencies
    for dep in jq git; do
        if command -v "$dep" &>/dev/null; then
            print_success "${dep} available"
            pass=$((pass + 1))
        else
            print_error "${dep} not found"
            fail=$((fail + 1))
        fi
    done

    if command -v fzf &>/dev/null; then
        print_success "fzf available (rewind enabled)"
        pass=$((pass + 1))
    else
        print_warn "fzf not found (rewind disabled)"
        warn=$((warn + 1))
    fi

    # Check config
    if [[ -f "${root}/${PENDING_DIR}/config.json" ]]; then
        print_success "Config present"
        pass=$((pass + 1))
    else
        print_error "Not enabled — run: checkpoints enable"
        fail=$((fail + 1))
    fi

    # Check orphan branch
    if git show-ref --quiet "refs/heads/${CHECKPOINT_BRANCH}" 2>/dev/null; then
        print_success "Orphan branch exists"
        pass=$((pass + 1))
    else
        print_error "Orphan branch missing"
        fail=$((fail + 1))
    fi

    # Check git hooks (common dir — shared across worktrees)
    local hooks_dir
    hooks_dir="$(git rev-parse --git-common-dir)/hooks"
    for hook_name in prepare-commit-msg post-commit pre-push; do
        if [[ -f "${hooks_dir}/${hook_name}" ]] && grep -q "checkpoints" "${hooks_dir}/${hook_name}" 2>/dev/null; then
            print_success "Git hook: ${hook_name}"
            pass=$((pass + 1))
        else
            print_error "Git hook: ${hook_name} missing"
            fail=$((fail + 1))
        fi
    done

    # Check hook scripts exist
    for hook_script in checkpoint-commit-msg.sh checkpoint-post-commit.sh checkpoint-pre-push.sh; do
        if [[ -f "${HOOKS_DIR}/${hook_script}" ]]; then
            print_success "Hook script: ${hook_script}"
            pass=$((pass + 1))
        else
            print_error "Hook script: ${hook_script} missing"
            fail=$((fail + 1))
        fi
    done

    # Check Claude session
    local session_file
    session_file=$(find_active_session 2>/dev/null || true)
    if [[ -n "$session_file" ]]; then
        print_success "Claude session detected"
        pass=$((pass + 1))
    else
        print_warn "No active Claude session"
        warn=$((warn + 1))
    fi

    echo ""
    echo -e "${GREEN}${pass} passed${NC}  ${RED}${fail} failed${NC}  ${YELLOW}${warn} warnings${NC}"
    [[ $fail -eq 0 ]] && return 0 || return 1
}

# --- Main ---

usage() {
    echo "Usage: checkpoints.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  enable [--strategy manual|auto]   Install checkpoint hooks"
    echo "  disable [--purge]                  Disable checkpoints (--purge removes shared git hooks)"
    echo "  status                             Show current checkpoint state"
    echo "  log [--branch <name>] [--git] [-n N] List checkpoints (--git: annotated git log)"
    echo "  show <commit-sha>                  Show checkpoint for a commit"
    echo "  resume [branch]                    Show latest checkpoint context for a branch"
    echo "  context [--commits N] [--branch b] Condensed context of recent checkpoints"
    echo "  search <query>                     Search checkpoint metadata and transcripts"
    echo "  rewind                             Interactive checkpoint browser"
    echo "  clean                              Remove orphaned checkpoint data"
    echo "  reset [--force]                    Delete checkpoint branch entirely"
    echo "  doctor                             Validate checkpoint setup"
    echo ""
    echo "Checkpoint data is stored on the '${CHECKPOINT_BRANCH}' orphan branch."
}

main() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        enable)  cmd_enable "$@" ;;
        disable) cmd_disable "$@" ;;
        status)  cmd_status ;;
        log)     cmd_log "$@" ;;
        show)    cmd_show "$@" ;;
        resume)  cmd_resume "$@" ;;
        context) cmd_context "$@" ;;
        search)  cmd_search "$@" ;;
        rewind)  cmd_rewind ;;
        clean)   cmd_clean ;;
        reset)   cmd_reset "$@" ;;
        doctor)  cmd_doctor ;;
        --help|-h|help|"")
            usage
            ;;
        *)
            print_error "Unknown command: ${cmd}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
