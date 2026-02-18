#!/usr/bin/env bash
#
# auto-merge.sh - Merge feature branch into main with additive conflict resolution
#
# From the main repo checkout, merges a feature branch INTO main.
# Automatically resolves conflicts ONLY when they are additive:
#   - Base ancestor is empty (new file added on both sides) -> take theirs (feature work)
#   - Only one side changed the file (other side matches base)
#
# If both sides modified existing content, merge is left in-progress
# so the caller can open nvim DiffviewOpen for manual resolution.
#
# Uses git object hashes (git ls-files -u) for comparison — binary-safe,
# zero I/O overhead vs content comparison.
#
# Usage:
#   auto-merge.sh <WORKTREE_PATH> [--repo-root DIR] [--dry-run] [--open-diffview SESSION:WINDOW]
#
# Exit codes:
#   0 - Merge completed successfully (or nothing to merge)
#   1 - Error (bad args, not a git repo, etc.)
#   2 - Non-additive conflicts, merge left in-progress (caller should open nvim)
#   3 - Uncommitted changes prevent merge

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
WORKTREE_PATH=""
REPO_ROOT=""
OPEN_DIFFVIEW=""

# Open DiffviewOpen in the nvim pane of the given tmux target
open_diffview() {
    [[ -z "$OPEN_DIFFVIEW" ]] && return 0
    local target="$OPEN_DIFFVIEW"
    local nvim_pane
    nvim_pane=$(tmux list-panes -t "$target" -F '#{pane_index} #{pane_current_command}' 2>/dev/null \
        | grep -i nvim | head -1 | awk '{print $1}')

    if [[ -n "$nvim_pane" ]]; then
        tmux send-keys -t "${target}.${nvim_pane}" Escape Enter
        sleep 0.3
        tmux send-keys -t "${target}.${nvim_pane}" \
            ":lua pcall(vim.cmd, 'DiffviewClose'); vim.cmd('cd $REPO_ROOT'); vim.cmd('checktime'); vim.cmd('DiffviewOpen')" Enter
        echo -e "${BLUE}Opened DiffviewOpen in nvim pane ${nvim_pane} (${target})${NC}"
    else
        echo -e "${YELLOW}Warning: No nvim pane found in $target, skipping DiffviewOpen${NC}" >&2
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-root)
            REPO_ROOT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --open-diffview)
            OPEN_DIFFVIEW="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: auto-merge.sh <WORKTREE_PATH> [--repo-root DIR] [--dry-run] [--open-diffview SESSION:WINDOW]"
            echo ""
            echo "Merges feature branch into main, auto-resolving additive-only conflicts."
            echo "Non-additive conflicts are left in-progress for manual resolution."
            echo ""
            echo "Options:"
            echo "  --repo-root DIR              Main repo checkout to merge into (default: derived from worktree)"
            echo "  --dry-run                    Check if merge is possible without committing"
            echo "  --open-diffview SESSION:WIN  Open DiffviewOpen in nvim pane on non-additive conflicts"
            echo "  --help                       Show this help"
            echo ""
            echo "Exit codes:"
            echo "  0 - Merge succeeded (or nothing to merge)"
            echo "  1 - Error"
            echo "  2 - Non-additive conflicts, merge left in-progress"
            echo "  3 - Uncommitted changes"
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            WORKTREE_PATH="$1"
            shift
            ;;
    esac
done

if [[ -z "$WORKTREE_PATH" ]]; then
    echo -e "${RED}Error: WORKTREE_PATH required${NC}" >&2
    exit 1
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo -e "${RED}Error: Not a directory: $WORKTREE_PATH${NC}" >&2
    exit 1
fi

# Determine feature branch from worktree
FEATURE_BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current)

if [[ -z "$FEATURE_BRANCH" ]]; then
    echo -e "${RED}Error: Could not determine feature branch in $WORKTREE_PATH${NC}" >&2
    exit 1
fi

# Derive main repo root from worktree's git common dir if not given
if [[ -z "$REPO_ROOT" ]]; then
    GIT_COMMON_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir)
    # git-common-dir gives the main repo's .git dir (absolute or relative)
    # The repo root is one level up from .git
    REPO_ROOT=$(cd "$WORKTREE_PATH" && cd "$GIT_COMMON_DIR/.." && pwd)
fi

if [[ ! -d "$REPO_ROOT/.git" ]] && ! git -C "$REPO_ROOT" rev-parse --git-dir &>/dev/null; then
    echo -e "${RED}Error: Not a git repository: $REPO_ROOT${NC}" >&2
    exit 1
fi

# Check what branch main repo is on
MAIN_BRANCH=$(git -C "$REPO_ROOT" branch --show-current)

if [[ -z "$MAIN_BRANCH" ]]; then
    echo -e "${RED}Error: Could not determine branch in main repo $REPO_ROOT${NC}" >&2
    exit 1
fi

if [[ "$FEATURE_BRANCH" == "$MAIN_BRANCH" ]]; then
    echo -e "${YELLOW}Feature branch is same as main repo branch ($MAIN_BRANCH), nothing to merge${NC}"
    exit 0
fi

# Work from main repo root
cd "$REPO_ROOT"

# Check for uncommitted changes in main repo (ignore untracked files)
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo -e "${RED}Error: Uncommitted changes in main repo prevent merge${NC}" >&2
    git status --short --untracked-files=no >&2
    exit 3
fi

echo -e "${BLUE}=== Auto-Merge ===${NC}"
echo -e "Feature: ${GREEN}$FEATURE_BRANCH${NC} (from $WORKTREE_PATH)"
echo -e "Into:    ${GREEN}$MAIN_BRANCH${NC} (at $REPO_ROOT)"
echo ""

# Check if merge is needed
MERGE_BASE=$(git merge-base "$MAIN_BRANCH" "$FEATURE_BRANCH" 2>/dev/null || true)
FEATURE_HEAD=$(git rev-parse "$FEATURE_BRANCH")

if [[ -z "$MERGE_BASE" ]]; then
    echo -e "${YELLOW}No common ancestor found, skipping merge${NC}"
    exit 0
fi

if [[ "$FEATURE_HEAD" == "$MERGE_BASE" ]]; then
    echo -e "${GREEN}Main is already up to date with $FEATURE_BRANCH${NC}"
    exit 0
fi

# Attempt merge of feature into main
echo "Attempting merge of $FEATURE_BRANCH into $MAIN_BRANCH..."

MERGE_RESULT=0
git merge --no-commit --no-ff "$FEATURE_BRANCH" 2>/dev/null || MERGE_RESULT=$?

if [[ $MERGE_RESULT -eq 0 ]]; then
    # Clean merge - no conflicts
    if $DRY_RUN; then
        echo -e "${GREEN}Dry run: merge would succeed cleanly${NC}"
        git merge --abort 2>/dev/null || true
        exit 0
    fi
    git commit --no-edit -m "merge: integrate $FEATURE_BRANCH into $MAIN_BRANCH"
    echo -e "${GREEN}Merged cleanly (no conflicts)${NC}"
    exit 0
fi

# Conflicts detected - check if they're all additive
echo -e "${YELLOW}Conflicts detected, analyzing...${NC}"
echo ""

CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)

if [[ -z "$CONFLICTED_FILES" ]]; then
    echo -e "${RED}Merge failed with no unmerged files (unexpected)${NC}" >&2
    git merge --abort
    exit 1
fi

# Parse git ls-files -u once, then extract hashes per file
# Stages: 1 = base (common ancestor), 2 = ours (main), 3 = theirs (feature)
UNMERGED=$(git ls-files -u)

ALL_ADDITIVE=true
NON_ADDITIVE_FILES=()
RESOLVED_COUNT=0

while IFS= read -r file; do
    echo -n "  $file: "

    # Extract object hashes for each stage
    # Format of ls-files -u: <mode> <hash> <stage> <file>
    BASE_HASH=$(echo "$UNMERGED" | awk "\$4 == \"$file\" && \$3 == 1 {print \$2}")
    OURS_HASH=$(echo "$UNMERGED" | awk "\$4 == \"$file\" && \$3 == 2 {print \$2}")
    THEIRS_HASH=$(echo "$UNMERGED" | awk "\$4 == \"$file\" && \$3 == 3 {print \$2}")

    if [[ -z "$BASE_HASH" ]]; then
        # No base = new file on both sides (additive) -> take theirs (feature's work)
        echo -e "${GREEN}new file (additive) -> taking theirs (feature)${NC}"
        git checkout --theirs -- "$file" 2>/dev/null || git show ":3:$file" > "$file"
        git add "$file"
        RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    elif [[ "$BASE_HASH" == "$OURS_HASH" ]]; then
        # Main didn't change this file, only feature did -> take theirs
        echo -e "${GREEN}main unchanged (additive) -> taking theirs (feature)${NC}"
        git checkout --theirs -- "$file" 2>/dev/null || git show ":3:$file" > "$file"
        git add "$file"
        RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    elif [[ "$BASE_HASH" == "$THEIRS_HASH" ]]; then
        # Feature didn't change this file, only main did -> take ours
        echo -e "${GREEN}feature unchanged (additive) -> taking ours (main)${NC}"
        git checkout --ours -- "$file" 2>/dev/null || git show ":2:$file" > "$file"
        git add "$file"
        RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    elif [[ -z "$OURS_HASH" ]] && [[ -n "$THEIRS_HASH" ]]; then
        # Main deleted, feature modified - not additive
        echo -e "${RED}deleted by main, modified by feature (NOT additive)${NC}"
        ALL_ADDITIVE=false
        NON_ADDITIVE_FILES+=("$file")
    elif [[ -n "$OURS_HASH" ]] && [[ -z "$THEIRS_HASH" ]]; then
        # Feature deleted, main modified - not additive
        echo -e "${RED}modified by main, deleted by feature (NOT additive)${NC}"
        ALL_ADDITIVE=false
        NON_ADDITIVE_FILES+=("$file")
    else
        # Both sides modified existing content differently
        echo -e "${RED}both sides modified (NOT additive)${NC}"
        ALL_ADDITIVE=false
        NON_ADDITIVE_FILES+=("$file")
    fi
done <<< "$CONFLICTED_FILES"

if ! $ALL_ADDITIVE; then
    echo ""
    echo -e "${RED}Non-additive conflicts found in:${NC}"
    for f in "${NON_ADDITIVE_FILES[@]}"; do
        echo -e "  - $f"
    done
    echo ""
    if $DRY_RUN; then
        echo -e "${YELLOW}Dry run: non-additive conflicts would need manual resolution${NC}"
        git merge --abort 2>/dev/null || true
        exit 2
    fi
    echo -e "${YELLOW}Merge left in-progress for manual resolution${NC}"
    echo -e "${YELLOW}Open nvim with DiffviewOpen to resolve, then commit${NC}"
    open_diffview
    exit 2
fi

# All conflicts were additive and resolved
if $DRY_RUN; then
    echo ""
    echo -e "${GREEN}Dry run: all $RESOLVED_COUNT conflict(s) are additive and resolvable${NC}"
    git merge --abort 2>/dev/null || true
    exit 0
fi

# Final safety check - ensure no unresolved conflicts remain
REMAINING=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
if [[ -n "$REMAINING" ]]; then
    echo -e "${RED}Unexpected unresolved conflicts remain${NC}" >&2
    echo -e "${YELLOW}Merge left in-progress for manual resolution${NC}"
    open_diffview
    exit 2
fi

# Commit the merge
git commit --no-edit -m "merge: integrate $FEATURE_BRANCH into $MAIN_BRANCH (additive conflicts resolved)"

echo ""
echo -e "${GREEN}Merge completed successfully${NC}"
echo -e "Resolved $RESOLVED_COUNT additive conflict(s)"
exit 0
