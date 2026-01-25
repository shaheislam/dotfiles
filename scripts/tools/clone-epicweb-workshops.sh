#!/usr/bin/env bash
# Clone EpicWeb Workshop Repositories
# Clones educational workshop repos from epicweb-dev for best practice references
#
# Usage: ./clone-epicweb-workshops.sh [OPTIONS]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_DIR="${HOME}/workshop"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
REPOS_CLONED=0
REPOS_SKIPPED=0
REPOS_FAILED=0

# Flags
DRY_RUN=false
FORCE_MODE=false

# ============================================================================
# Workshop Repository List
# ============================================================================
WORKSHOPS=(
  "beginner-javascript"
  "web-auth"
  "advanced-react-apis"
  "advanced-react-patterns"
  "advanced-vitest-patterns"
  "build-react-hooks"
  "advanced-typescript"
  "structured-data"
  "object-oriented-typescript"
  "type-safety"
  "data-modeling"
  "epicshop-tutorial"
  "get-started-with-react"
  "e2e-react-application-testing-with-playwright"
  "full-stack-testing"
  "full-stack-foundations"
  "mcp-auth"
  "mcp-fundamentals"
  "mcp-ui"
  "pixel-perfect-tailwind"
  "mocking-techniques"
  "react-hooks"
  "react-fundamentals"
  "react-and-the-vanishing-network"
  "react-component-testing-with-vitest"
  "react-performance"
  "react-server-components"
  "react-router-fundamentals-pt-1"
  "react-suspense"
  "programming-foundations"
  "testing-fundamentals"
  "web-forms"
  "get-started-with-react-router"
  "web-app-fundamentals"
  "testing-web-apps"
  "creative-coding"
  "design-iteration"
  "advanced-react-router"
)

# ============================================================================
# Helper Functions
# ============================================================================
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_skip() {
    echo -e "  ${YELLOW}⏭${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

show_help() {
    cat << EOF
Clone EpicWeb Workshop Repositories

Clones educational workshop repos from epicweb-dev into ~/workshop
for use as best practice references.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run       Preview what would be cloned without making changes
    --force         Re-clone existing repos (removes and clones fresh)
    -h, --help      Show this help message

EXAMPLES:
    $0                  # Clone all workshops
    $0 --dry-run        # Preview without cloning
    $0 --force          # Force re-clone all repos

REQUIREMENTS:
    - GitHub CLI (gh) must be installed and authenticated

EOF
}

# ============================================================================
# Main Functions
# ============================================================================
check_requirements() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
        echo "Install with: brew install gh"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI is not authenticated${NC}"
        echo "Run: gh auth login"
        exit 1
    fi
}

ensure_workshop_dir() {
    if [[ ! -d "$WORKSHOP_DIR" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            print_info "Would create directory: $WORKSHOP_DIR"
        else
            mkdir -p "$WORKSHOP_DIR"
            print_success "Created directory: $WORKSHOP_DIR"
        fi
    fi
}

clone_repo() {
    local repo="$1"
    local target_name="workshop-${repo}"
    local target_path="${WORKSHOP_DIR}/${target_name}"

    if [[ -d "$target_path" ]]; then
        if [[ "$FORCE_MODE" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                print_info "Would remove and re-clone: $target_name"
                ((REPOS_CLONED++))
            else
                rm -rf "$target_path"
                if gh repo clone "epicweb-dev/${repo}" "$target_path" 2>/dev/null; then
                    print_success "Re-cloned: $target_name"
                    ((REPOS_CLONED++))
                else
                    print_error "Failed to clone: $repo"
                    ((REPOS_FAILED++))
                fi
            fi
        else
            print_skip "Already exists: $target_name"
            ((REPOS_SKIPPED++))
        fi
    else
        if [[ "$DRY_RUN" == true ]]; then
            print_info "Would clone: epicweb-dev/${repo} -> $target_name"
            ((REPOS_CLONED++))
        else
            if gh repo clone "epicweb-dev/${repo}" "$target_path" 2>/dev/null; then
                print_success "Cloned: $target_name"
                ((REPOS_CLONED++))
            else
                print_error "Failed to clone: $repo"
                ((REPOS_FAILED++))
            fi
        fi
    fi
}

# ============================================================================
# Argument Parsing
# ============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ============================================================================
# Main Execution
# ============================================================================
print_header "EpicWeb Workshop Cloner"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
    echo ""
fi

check_requirements
ensure_workshop_dir

echo ""
echo "Found ${#WORKSHOPS[@]} workshop repositories"
echo "Target directory: $WORKSHOP_DIR"
echo ""

for repo in "${WORKSHOPS[@]}"; do
    clone_repo "$repo"
done

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "Would clone: ${GREEN}${REPOS_CLONED}${NC}"
else
    echo -e "Cloned:  ${GREEN}${REPOS_CLONED}${NC}"
fi
echo -e "Skipped: ${YELLOW}${REPOS_SKIPPED}${NC}"
echo -e "Failed:  ${RED}${REPOS_FAILED}${NC}"

if [[ $REPOS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
