#!/usr/bin/env bash
#
# auto-merge.sh - Attempt merge with additive-only conflict resolution
#
# Merges target branch (default: main) INTO the current feature branch,
# automatically resolving conflicts ONLY when they are additive:
#   - Base ancestor is empty (new file added on both sides)
#   - Only one side changed the file (other side matches base)
#
# If both sides modified existing content, merge is aborted to prevent data loss.
#
# Usage:
#   auto-merge.sh <WORKTREE_PATH> [--target BRANCH] [--dry-run]
#
# Exit codes:
#   0 - Merge completed successfully
#   1 - Error (bad args, not a git repo, etc.)
#   2 - Non-additive conflicts found, merge aborted
#   3 - Uncommitted changes prevent merge

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_BRANCH="main"
DRY_RUN=false
WORKTREE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: auto-merge.sh <WORKTREE_PATH> [--target BRANCH] [--dry-run]"
            echo ""
            echo "Merges target branch into feature branch, auto-resolving additive-only conflicts."
            echo "Aborts if any conflict involves both sides modifying existing code."
            echo ""
            echo "Options:"
            echo "  --target BRANCH  Target branch to merge from (default: main)"
            echo "  --dry-run        Check if merge is possible without committing"
            echo "  --help           Show this help"
            echo ""
            echo "Exit codes:"
            echo "  0 - Merge succeeded"
            echo "  1 - Error"
            echo "  2 - Non-additive conflicts, merge aborted"
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

cd "$WORKTREE_PATH"

if ! git rev-parse --git-dir &>/dev/null; then
    echo -e "${RED}Error: Not a git repository: $WORKTREE_PATH${NC}" >&2
    exit 1
fi

FEATURE_BRANCH=$(git branch --show-current)

if [[ -z "$FEATURE_BRANCH" ]]; then
    echo -e "${RED}Error: Could not determine current branch${NC}" >&2
    exit 1
fi

if [[ "$FEATURE_BRANCH" == "$TARGET_BRANCH" ]]; then
    echo -e "${YELLOW}Already on $TARGET_BRANCH, nothing to merge${NC}"
    exit 0
fi

# Check for uncommitted changes
if [[ -n "$(git status --porcelain)" ]]; then
    echo -e "${RED}Error: Uncommitted changes prevent merge${NC}" >&2
    git status --short >&2
    exit 3
fi

echo -e "${BLUE}=== Auto-Merge ===${NC}"
echo -e "Feature: ${GREEN}$FEATURE_BRANCH${NC}"
echo -e "Target:  ${GREEN}$TARGET_BRANCH${NC}"
echo ""

# Fetch latest target branch
echo "Fetching latest $TARGET_BRANCH..."
git fetch origin "$TARGET_BRANCH" 2>/dev/null || true

# Resolve target ref (prefer origin/TARGET if available)
TARGET_REF="origin/$TARGET_BRANCH"
if ! git rev-parse "$TARGET_REF" &>/dev/null; then
    TARGET_REF="$TARGET_BRANCH"
fi

# Check if merge is needed
MERGE_BASE=$(git merge-base "$TARGET_REF" "$FEATURE_BRANCH" 2>/dev/null || true)
TARGET_HEAD=$(git rev-parse "$TARGET_REF")

if [[ -z "$MERGE_BASE" ]]; then
    echo -e "${YELLOW}No common ancestor found, skipping merge${NC}"
    exit 0
fi

if [[ "$TARGET_HEAD" == "$MERGE_BASE" ]]; then
    echo -e "${GREEN}Feature branch is already up to date with $TARGET_BRANCH${NC}"
    exit 0
fi

# Attempt merge of target into feature branch
echo "Attempting merge of $TARGET_BRANCH into $FEATURE_BRANCH..."

MERGE_RESULT=0
git merge --no-commit --no-ff "$TARGET_REF" 2>/dev/null || MERGE_RESULT=$?

if [[ $MERGE_RESULT -eq 0 ]]; then
    # Clean merge - no conflicts
    if $DRY_RUN; then
        echo -e "${GREEN}Dry run: merge would succeed cleanly${NC}"
        git merge --abort 2>/dev/null || true
        exit 0
    fi
    git commit --no-edit -m "merge: bring $FEATURE_BRANCH up to date with $TARGET_BRANCH"
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

# Analyze each conflicted file using git's 3-way merge stages:
#   Stage 1 = base (common ancestor)
#   Stage 2 = ours (current branch = feature)
#   Stage 3 = theirs (merge source = target/main)
#
# Additive patterns we can safely resolve:
#   - Base empty (new file): take ours (feature work takes priority)
#   - Base == theirs (target unchanged): take ours
#   - Base == ours (feature unchanged): take theirs
#   - Both modified existing content: NOT additive, abort

ALL_ADDITIVE=true
NON_ADDITIVE_FILES=()
RESOLVED_COUNT=0

while IFS= read -r file; do
    echo -n "  $file: "

    # Get content for each stage (empty string if stage doesn't exist = file is new)
    # Stage 1 = base, Stage 2 = ours (feature), Stage 3 = theirs (target)
    BASE_CONTENT=$(git show ":1:$file" 2>/dev/null || true)
    OURS_CONTENT=$(git show ":2:$file" 2>/dev/null || true)
    THEIRS_CONTENT=$(git show ":3:$file" 2>/dev/null || true)

    if [[ -z "$BASE_CONTENT" ]]; then
        # No base = new file on both sides (additive)
        echo -e "${GREEN}new file (additive) -> taking ours${NC}"
        git checkout --ours -- "$file" 2>/dev/null || git show ":2:$file" > "$file"
        git add "$file"
        RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    elif [[ "$BASE_CONTENT" == "$THEIRS_CONTENT" ]]; then
        # Target didn't change this file, only we did
        echo -e "${GREEN}target unchanged (additive) -> taking ours${NC}"
        git checkout --ours -- "$file" 2>/dev/null || git show ":2:$file" > "$file"
        git add "$file"
        RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    elif [[ "$BASE_CONTENT" == "$OURS_CONTENT" ]]; then
        # We didn't change this file, only target did
        echo -e "${GREEN}feature unchanged (additive) -> taking theirs${NC}"
        git checkout --theirs -- "$file" 2>/dev/null || git show ":3:$file" > "$file"
        git add "$file"
        RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    elif [[ -z "$OURS_CONTENT" ]] && [[ -n "$THEIRS_CONTENT" ]]; then
        # We deleted, they modified - not additive
        echo -e "${RED}deleted by us, modified by them (NOT additive)${NC}"
        ALL_ADDITIVE=false
        NON_ADDITIVE_FILES+=("$file")
    elif [[ -n "$OURS_CONTENT" ]] && [[ -z "$THEIRS_CONTENT" ]]; then
        # They deleted, we modified - not additive
        echo -e "${RED}modified by us, deleted by them (NOT additive)${NC}"
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
    echo -e "${YELLOW}Aborting merge to prevent data loss${NC}"
    git merge --abort
    exit 2
fi

# All conflicts were additive and resolved
if $DRY_RUN; then
    echo ""
    echo -e "${GREEN}Dry run: all $RESOLVED_COUNT conflict(s) are additive and resolvable${NC}"
    git merge --abort 2>/dev/null || git reset --hard HEAD
    exit 0
fi

# Final safety check - ensure no unresolved conflicts remain
REMAINING=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
if [[ -n "$REMAINING" ]]; then
    echo -e "${RED}Unexpected unresolved conflicts remain, aborting${NC}" >&2
    git merge --abort
    exit 2
fi

# Commit the merge
git commit --no-edit -m "merge: resolve additive conflicts, bring $FEATURE_BRANCH up to date with $TARGET_BRANCH"

echo ""
echo -e "${GREEN}Merge completed successfully${NC}"
echo -e "Resolved $RESOLVED_COUNT additive conflict(s)"
exit 0
