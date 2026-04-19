#!/usr/bin/env bash
# Mass git branch operations across all repos in current directory
#
# Usage: git-mass-branch.sh <branch-name> [OPTIONS]
#
# Arguments:
#   <branch-name>  Name of the new branch to create
#
# Options:
#   --dry-run      Show what would be done without executing
#   --help         Show this help message
#
# Operations performed on each repo:
#   1. git stash
#   2. git checkout <default-branch>
#   3. git pull origin <default-branch>
#   4. git checkout -b <branch-name>
#
# Examples:
#   cd ~/work
#   git-mass-branch.sh 2544-pin-third-party-actions-in-github-actions
#   git-mass-branch.sh feature/new-dashboard --dry-run

# Note: Not using 'set -e' to allow script to continue processing repos even if some fail
# Individual repo failures are tracked in FAILED_REPOS array

# Configuration
WORK_DIR="$(pwd)"
TARGET_BRANCH=""
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_REPOS=0
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
declare -a FAILED_REPOS
declare -a SKIPPED_REPOS

# Parse arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--help)
		grep '^#' "$0" | sed 's/^# \?//'
		exit 0
		;;
	-*)
		echo "Unknown option: $1"
		echo "Use --help for usage information"
		exit 1
		;;
	*)
		# Positional argument - branch name
		if [ -z "$TARGET_BRANCH" ]; then
			TARGET_BRANCH="$1"
		else
			echo "Error: Multiple branch names provided"
			echo "Use --help for usage information"
			exit 1
		fi
		shift
		;;
	esac
done

# Validate required arguments
if [ -z "$TARGET_BRANCH" ]; then
	echo "Error: Branch name is required"
	echo ""
	grep '^#' "$0" | sed 's/^# \?//'
	exit 1
fi

# Function to get default branch for a repo
get_default_branch() {
	local repo_dir=$1
	local default_branch

	# Try git config init.defaultBranch first
	default_branch=$(git -C "$repo_dir" config --get init.defaultBranch 2>/dev/null || true)

	# Check if the configured default branch exists
	if [ -n "$default_branch" ] && git -C "$repo_dir" show-ref -q --verify "refs/heads/$default_branch" 2>/dev/null; then
		echo "$default_branch"
		return 0
	fi

	# Try 'main'
	if git -C "$repo_dir" show-ref -q --verify refs/heads/main 2>/dev/null; then
		echo "main"
		return 0
	fi

	# Fall back to 'master'
	echo "master"
	return 0
}

# Function to process a single repo
process_repo() {
	local repo_dir=$1
	local repo_name
	repo_name=$(basename "$repo_dir")

	echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${BLUE}Processing: $repo_name${NC}"
	echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

	# Check if target branch already exists
	if git -C "$repo_dir" show-ref -q --verify "refs/heads/$TARGET_BRANCH" 2>/dev/null; then
		echo -e "${YELLOW}⏭️  Skipping: Branch '$TARGET_BRANCH' already exists${NC}"
		SKIPPED_REPOS+=("$repo_name (branch exists)")
		((SKIP_COUNT++)) || true
		return 0
	fi

	# Get default branch
	local default_branch
	default_branch=$(get_default_branch "$repo_dir")
	echo -e "Default branch: ${GREEN}$default_branch${NC}"

	# Check if there are uncommitted changes
	if ! git -C "$repo_dir" diff-index --quiet HEAD -- 2>/dev/null; then
		echo -e "${YELLOW}📦 Stashing changes...${NC}"
		if [ "$DRY_RUN" = false ]; then
			if ! git -C "$repo_dir" stash push -m "Auto-stash before branch creation: $TARGET_BRANCH" 2>&1; then
				echo -e "${RED}❌ Failed to stash changes${NC}"
				FAILED_REPOS+=("$repo_name (stash failed)")
				((FAIL_COUNT++)) || true
				return 1
			fi
			echo -e "${GREEN}✅ Changes stashed${NC}"
		else
			echo -e "[DRY RUN] Would stash changes"
		fi
	else
		echo -e "${GREEN}✓ No uncommitted changes${NC}"
	fi

	# Checkout default branch
	echo -e "${YELLOW}🔄 Checking out $default_branch...${NC}"
	if [ "$DRY_RUN" = false ]; then
		if ! git -C "$repo_dir" checkout "$default_branch" 2>&1; then
			echo -e "${RED}❌ Failed to checkout $default_branch${NC}"
			FAILED_REPOS+=("$repo_name (checkout failed)")
			((FAIL_COUNT++)) || true
			return 1
		fi
		echo -e "${GREEN}✅ Checked out $default_branch${NC}"
	else
		echo -e "[DRY RUN] Would checkout $default_branch"
	fi

	# Pull latest changes
	echo -e "${YELLOW}⬇️  Pulling latest changes...${NC}"
	if [ "$DRY_RUN" = false ]; then
		if ! git -C "$repo_dir" pull origin "$default_branch" 2>&1; then
			echo -e "${RED}❌ Failed to pull from origin/$default_branch${NC}"
			FAILED_REPOS+=("$repo_name (pull failed)")
			((FAIL_COUNT++)) || true
			return 1
		fi
		echo -e "${GREEN}✅ Pulled latest changes${NC}"
	else
		echo -e "[DRY RUN] Would pull from origin/$default_branch"
	fi

	# Create new branch
	echo -e "${YELLOW}🌿 Creating branch: $TARGET_BRANCH...${NC}"
	if [ "$DRY_RUN" = false ]; then
		if ! git -C "$repo_dir" checkout -b "$TARGET_BRANCH" 2>&1; then
			echo -e "${RED}❌ Failed to create branch $TARGET_BRANCH${NC}"
			FAILED_REPOS+=("$repo_name (branch creation failed)")
			((FAIL_COUNT++)) || true
			return 1
		fi
		echo -e "${GREEN}✅ Created and checked out branch: $TARGET_BRANCH${NC}"
	else
		echo -e "[DRY RUN] Would create branch: $TARGET_BRANCH"
	fi

	echo -e "${GREEN}✅ Successfully processed $repo_name${NC}"
	((SUCCESS_COUNT++)) || true
	return 0
}

# Main execution
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Mass Git Branch Operations                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Work directory: ${BLUE}$WORK_DIR${NC}"
echo -e "Target branch:  ${GREEN}$TARGET_BRANCH${NC}"
if [ "$DRY_RUN" = true ]; then
	echo -e "Mode:          ${YELLOW}DRY RUN (no changes will be made)${NC}"
fi
echo ""

# Check if directory exists
if [ ! -d "$WORK_DIR" ]; then
	echo -e "${RED}Error: Directory does not exist: $WORK_DIR${NC}"
	exit 1
fi

# Find all git repositories
echo -e "${BLUE}Scanning for git repositories...${NC}"
while IFS= read -r -d '' git_dir; do
	repo_dir=$(dirname "$git_dir")
	((TOTAL_REPOS++)) || true

	# Process repo (continue on failure)
	process_repo "$repo_dir" || true

done < <(find "$WORK_DIR" -maxdepth 2 -type d -name ".git" -print0)

# Print summary
echo -e "\n${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Summary                                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total repositories: ${BLUE}$TOTAL_REPOS${NC}"
echo -e "Successful:         ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "Skipped:            ${YELLOW}$SKIP_COUNT${NC}"
echo -e "Failed:             ${RED}$FAIL_COUNT${NC}"

if [ ${#SKIPPED_REPOS[@]} -gt 0 ]; then
	echo -e "\n${YELLOW}Skipped repositories:${NC}"
	for repo in "${SKIPPED_REPOS[@]}"; do
		echo -e "  ${YELLOW}⏭️  $repo${NC}"
	done
fi

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
	echo -e "\n${RED}Failed repositories:${NC}"
	for repo in "${FAILED_REPOS[@]}"; do
		echo -e "  ${RED}❌ $repo${NC}"
	done
	exit 1
fi

echo -e "\n${GREEN}✅ All operations completed successfully!${NC}"
exit 0
