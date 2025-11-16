#!/usr/bin/env bash
# Repository Healthcheck Scanner
# Scans all git repositories under ~/work for configuration issues
# Checks: git exclude symlinks, Nix flake configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
WORK_DIR="${WORK_DIR:-$HOME/work}"
FLAKE_LOCK_MAX_AGE_DAYS=90

# Flags
DRY_RUN=false
VERBOSE=false
QUIET=false
FAILURES_ONLY=false

# Track results
REPOS_SCANNED=0
REPOS_WITH_ISSUES=0
ISSUES_FOUND=0
FIXES_APPLIED=0
FIXES_DECLINED=0

# Issue tracking arrays
declare -a REPOS  # All discovered repositories
declare -a REPOS_MISSING_SYMLINK
declare -a REPOS_SYMLINK_WRONG_TARGET
declare -a REPOS_MISSING_SELF_REFERENCE
declare -a REPOS_MISSING_FLAKE
declare -a REPOS_STALE_FLAKE_LOCK
declare -a REPOS_CLEAN

# Helper functions
print_header() {
    [[ "$QUIET" == true ]] && return
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_repo_header() {
    [[ "$QUIET" == true ]] && return
    echo ""
    echo -e "${CYAN}📁 $1${NC}"
}

print_success() {
    [[ "$QUIET" == true ]] && return
    [[ "$FAILURES_ONLY" == true ]] && return
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    [[ "$QUIET" == true ]] && return
    echo -e "  ${RED}✗${NC} $1"
}

print_warning() {
    [[ "$QUIET" == true ]] && return
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    [[ "$QUIET" == true ]] && return
    [[ "$VERBOSE" == false ]] && return
    echo -e "  ${BLUE}ℹ${NC} $1"
}

print_fix() {
    [[ "$QUIET" == true ]] && return
    echo -e "  ${CYAN}🔧${NC} $1"
}

prompt_fix() {
    local message="$1"
    local default="${2:-n}"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Dry-run: Would prompt to fix: $message"
        return 1
    fi

    echo -ne "  ${CYAN}🔧 ${message} (y/N)?${NC} "
    read -r response
    response="${response:-$default}"

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        ((FIXES_DECLINED++))
        return 1
    fi
}

# Find all git repositories under work directory
# Populates the global REPOS array
find_git_repos() {
    if [[ ! -d "$WORK_DIR" ]]; then
        echo -e "${RED}Error: Work directory not found: $WORK_DIR${NC}"
        exit 1
    fi

    print_info "Scanning for git repositories in $WORK_DIR..."

    # Find all .git directories, excluding submodules
    while IFS= read -r git_dir; do
        # Get the repository root (parent of .git)
        local repo_root
        repo_root=$(dirname "$git_dir")

        # Skip if this is a submodule (has a .git file instead of directory)
        if [[ -f "$repo_root/.git" ]]; then
            print_info "Skipping submodule: $repo_root"
            continue
        fi

        REPOS+=("$repo_root")
    done < <(find "$WORK_DIR" -name .git -type d 2>/dev/null)
}

# Check if .gitignore_local symlink exists and points to .git/info/exclude
check_git_exclude_symlink() {
    local repo_root="$1"
    local gitignore_local="$repo_root/.gitignore_local"
    local git_exclude="$repo_root/.git/info/exclude"

    # Check if symlink exists
    if [[ ! -L "$gitignore_local" ]]; then
        print_error "Missing .gitignore_local symlink"
        REPOS_MISSING_SYMLINK+=("$repo_root")
        ((ISSUES_FOUND++))
        return 1
    fi

    # Check if symlink points to correct target
    local target
    target=$(readlink "$gitignore_local")

    if [[ "$target" != ".git/info/exclude" ]]; then
        print_error ".gitignore_local points to wrong target: $target (expected: .git/info/exclude)"
        REPOS_SYMLINK_WRONG_TARGET+=("$repo_root")
        ((ISSUES_FOUND++))
        return 1
    fi

    print_success ".gitignore_local symlink configured correctly"
    return 0
}

# Check if .gitignore_local is referenced in .git/info/exclude
check_git_exclude_content() {
    local repo_root="$1"
    local git_exclude="$repo_root/.git/info/exclude"

    # Ensure .git/info/exclude exists
    if [[ ! -f "$git_exclude" ]]; then
        print_warning ".git/info/exclude file missing"
        return 1
    fi

    # Check if .gitignore_local is listed in exclude
    if grep -q "^\.gitignore_local$" "$git_exclude" 2>/dev/null; then
        print_success ".gitignore_local listed in git exclude"
        return 0
    else
        print_error ".gitignore_local not found in .git/info/exclude"
        REPOS_MISSING_SELF_REFERENCE+=("$repo_root")
        ((ISSUES_FOUND++))
        return 1
    fi
}

# Check if flake.nix exists
check_nix_flake_exists() {
    local repo_root="$1"
    local flake_file="$repo_root/flake.nix"

    if [[ -f "$flake_file" ]]; then
        print_success "flake.nix exists"
        return 0
    else
        print_info "No flake.nix found (informational)"
        REPOS_MISSING_FLAKE+=("$repo_root")
        return 1
    fi
}

# Check if flake.lock is up-to-date
check_nix_flake_lock_age() {
    local repo_root="$1"
    local flake_lock="$repo_root/flake.lock"

    if [[ ! -f "$flake_lock" ]]; then
        print_info "No flake.lock found"
        return 1
    fi

    # Get file modification time
    local lock_age_days
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS stat
        lock_age_days=$(( ($(date +%s) - $(stat -f %m "$flake_lock")) / 86400 ))
    else
        # Linux stat
        lock_age_days=$(( ($(date +%s) - $(stat -c %Y "$flake_lock")) / 86400 ))
    fi

    if [[ $lock_age_days -gt $FLAKE_LOCK_MAX_AGE_DAYS ]]; then
        print_warning "flake.lock is ${lock_age_days} days old (threshold: ${FLAKE_LOCK_MAX_AGE_DAYS} days)"
        REPOS_STALE_FLAKE_LOCK+=("$repo_root")
        ((ISSUES_FOUND++))
        return 1
    else
        print_success "flake.lock is up-to-date (${lock_age_days} days old)"
        return 0
    fi
}

# Fix: Create .gitignore_local symlink
fix_git_exclude_symlink() {
    local repo_root="$1"
    local gitignore_local="$repo_root/.gitignore_local"
    local git_exclude="$repo_root/.git/info/exclude"

    # Ensure .git/info directory exists
    mkdir -p "$repo_root/.git/info"

    # Create .git/info/exclude if it doesn't exist
    if [[ ! -f "$git_exclude" ]]; then
        touch "$git_exclude"
    fi

    # Remove existing file/symlink if present
    if [[ -e "$gitignore_local" ]]; then
        rm -f "$gitignore_local"
    fi

    # Create symlink
    if ln -s .git/info/exclude "$gitignore_local" 2>/dev/null; then
        print_fix "Created .gitignore_local symlink"
        ((FIXES_APPLIED++))
        return 0
    else
        print_error "Failed to create .gitignore_local symlink"
        return 1
    fi
}

# Fix: Add .gitignore_local to .git/info/exclude
fix_git_exclude_content() {
    local repo_root="$1"
    local git_exclude="$repo_root/.git/info/exclude"

    # Ensure .git/info/exclude exists
    if [[ ! -f "$git_exclude" ]]; then
        mkdir -p "$repo_root/.git/info"
        touch "$git_exclude"
    fi

    # Add .gitignore_local to exclude if not present
    if ! grep -q "^\.gitignore_local$" "$git_exclude" 2>/dev/null; then
        echo ".gitignore_local" >> "$git_exclude"
        print_fix "Added .gitignore_local to .git/info/exclude"
        ((FIXES_APPLIED++))
        return 0
    fi

    return 0
}

# Fix: Update flake.lock
fix_nix_flake_lock() {
    local repo_root="$1"

    if [[ ! -f "$repo_root/flake.nix" ]]; then
        print_error "Cannot update flake.lock: flake.nix not found"
        return 1
    fi

    print_fix "Updating flake.lock..."
    if (cd "$repo_root" && nix flake update 2>/dev/null); then
        print_fix "flake.lock updated successfully"
        ((FIXES_APPLIED++))
        return 0
    else
        print_error "Failed to update flake.lock"
        return 1
    fi
}

# Run healthchecks on a single repository
healthcheck_repo() {
    local repo_root="$1"
    local repo_name
    repo_name=$(basename "$repo_root")

    ((REPOS_SCANNED++))

    print_repo_header "$repo_name ($repo_root)"

    local has_issues=false

    # Git exclude symlink check
    if ! check_git_exclude_symlink "$repo_root"; then
        has_issues=true
        if prompt_fix "Create .gitignore_local symlink"; then
            fix_git_exclude_symlink "$repo_root"
        fi
    fi

    # Git exclude content check
    if ! check_git_exclude_content "$repo_root"; then
        has_issues=true
        if prompt_fix "Add .gitignore_local to .git/info/exclude"; then
            fix_git_exclude_content "$repo_root"
        fi
    fi

    # Nix flake checks
    local has_flake=false
    if check_nix_flake_exists "$repo_root"; then
        has_flake=true

        if ! check_nix_flake_lock_age "$repo_root"; then
            has_issues=true
            if prompt_fix "Update flake.lock"; then
                fix_nix_flake_lock "$repo_root"
            fi
        fi
    fi

    # Track clean repos
    if [[ "$has_issues" == false ]]; then
        REPOS_CLEAN+=("$repo_root")
        if [[ "$FAILURES_ONLY" == false ]]; then
            print_success "Repository is healthy"
        fi
    else
        ((REPOS_WITH_ISSUES++))
    fi
}

# Print summary report
print_summary() {
    print_header "Summary Report"

    echo -e "${CYAN}Repositories Scanned:${NC} $REPOS_SCANNED"
    echo -e "${CYAN}Repositories with Issues:${NC} $REPOS_WITH_ISSUES"
    echo -e "${CYAN}Clean Repositories:${NC} ${#REPOS_CLEAN[@]}"
    echo ""
    echo -e "${CYAN}Total Issues Found:${NC} $ISSUES_FOUND"
    echo -e "${CYAN}Fixes Applied:${NC} $FIXES_APPLIED"
    echo -e "${CYAN}Fixes Declined:${NC} $FIXES_DECLINED"
    echo ""

    # Issue breakdown
    if [[ ${#REPOS_MISSING_SYMLINK[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing .gitignore_local symlink (${#REPOS_MISSING_SYMLINK[@]}):${NC}"
        for repo in "${REPOS_MISSING_SYMLINK[@]}"; do
            echo "  - $(basename "$repo")"
        done
        echo ""
    fi

    if [[ ${#REPOS_SYMLINK_WRONG_TARGET[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Wrong symlink target (${#REPOS_SYMLINK_WRONG_TARGET[@]}):${NC}"
        for repo in "${REPOS_SYMLINK_WRONG_TARGET[@]}"; do
            echo "  - $(basename "$repo")"
        done
        echo ""
    fi

    if [[ ${#REPOS_MISSING_SELF_REFERENCE[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing .gitignore_local in exclude (${#REPOS_MISSING_SELF_REFERENCE[@]}):${NC}"
        for repo in "${REPOS_MISSING_SELF_REFERENCE[@]}"; do
            echo "  - $(basename "$repo")"
        done
        echo ""
    fi

    if [[ ${#REPOS_MISSING_FLAKE[@]} -gt 0 ]] && [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}Repositories without Nix flake (${#REPOS_MISSING_FLAKE[@]}):${NC}"
        for repo in "${REPOS_MISSING_FLAKE[@]}"; do
            echo "  - $(basename "$repo")"
        done
        echo ""
    fi

    if [[ ${#REPOS_STALE_FLAKE_LOCK[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Stale flake.lock (${#REPOS_STALE_FLAKE_LOCK[@]}):${NC}"
        for repo in "${REPOS_STALE_FLAKE_LOCK[@]}"; do
            echo "  - $(basename "$repo")"
        done
        echo ""
    fi

    # Overall status
    if [[ $REPOS_WITH_ISSUES -eq 0 ]]; then
        echo -e "${GREEN}✓ All repositories are healthy!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ Found issues in $REPOS_WITH_ISSUES repositories${NC}"
        exit 1
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Repository Healthcheck Scanner
Scans all git repositories under ~/work for configuration issues

Options:
    --dry-run           Report issues without offering fixes
    --verbose           Show all checks including informational messages
    --quiet             Show only summary statistics
    --failures-only     Show only repositories with issues
    --work-dir DIR      Override work directory (default: ~/work)
    --help              Show this help message

Healthchecks:
    ✓ Git exclude symlink (.gitignore_local → .git/info/exclude)
    ✓ Git exclude content (.gitignore_local listed in exclude)
    ✓ Nix flake existence (flake.nix)
    ✓ Nix flake lock age (flake.lock < 90 days)

Examples:
    # Run full healthcheck with interactive fixes
    $(basename "$0")

    # Report only (no fixes)
    $(basename "$0") --dry-run

    # Show only repos with issues
    $(basename "$0") --failures-only

    # Verbose mode (show all checks)
    $(basename "$0") --verbose

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --failures-only)
            FAILURES_ONLY=true
            shift
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Main execution
print_header "Repository Healthcheck Scanner"
echo -e "${CYAN}Work Directory:${NC} $WORK_DIR"
echo -e "${CYAN}Mode:${NC} $([ "$DRY_RUN" == true ] && echo "Dry-run (report only)" || echo "Interactive (with fixes)")"

# Find all repositories (populates global REPOS array)
find_git_repos

if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No git repositories found in $WORK_DIR${NC}"
    exit 0
fi

print_info "Found ${#REPOS[@]} repositories"

# Run healthchecks on each repository
for repo in "${REPOS[@]}"; do
    healthcheck_repo "$repo"
done

# Print summary
print_summary
