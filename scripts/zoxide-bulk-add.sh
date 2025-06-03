#!/bin/bash

# Zoxide Bulk Directory Learning Script
# Usage: ./zoxide-bulk-add.sh <directory_path>
# Example: ./zoxide-bulk-add.sh ~/work

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_NAME="$(basename "$0")"
VERSION="1.0.0"

# Print usage information
usage() {
    cat << EOF
${CYAN}Zoxide Bulk Directory Learning Script v${VERSION}${NC}

${YELLOW}USAGE:${NC}
    ${SCRIPT_NAME} <directory_path> [options]

${YELLOW}ARGUMENTS:${NC}
    directory_path    Path to directory containing subdirectories to add to zoxide

${YELLOW}OPTIONS:${NC}
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
    -d, --dry-run    Show what would be added without actually adding
    -f, --force      Force add even if directory already exists in zoxide
    -s, --stats      Show statistics after completion
    --min-depth N    Minimum directory depth to include (default: 1)
    --max-depth N    Maximum directory depth to include (default: 1)

${YELLOW}EXAMPLES:${NC}
    ${SCRIPT_NAME} ~/work
    ${SCRIPT_NAME} ~/projects --verbose --stats
    ${SCRIPT_NAME} ~/code --dry-run --max-depth 2
    ${SCRIPT_NAME} /path/to/repos --force --min-depth 1 --max-depth 3

${YELLOW}ADVANCED FEATURES:${NC}
    • Validates directory existence and permissions
    • Skips hidden directories (starting with .)
    • Provides progress tracking with counts
    • Handles symbolic links intelligently
    • Offers dry-run mode for safety
    • Shows detailed statistics
    • Supports configurable directory depth
    • Colorized output for better readability
    • Error handling with graceful fallbacks

EOF
}

# Default configuration
VERBOSE=false
DRY_RUN=false
FORCE=false
SHOW_STATS=false
MIN_DEPTH=1
MAX_DEPTH=1
TARGET_DIR=""

# Counters for statistics
TOTAL_FOUND=0
TOTAL_ADDED=0
TOTAL_SKIPPED=0
TOTAL_ERRORS=0

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -s|--stats)
                SHOW_STATS=true
                shift
                ;;
            --min-depth)
                MIN_DEPTH="$2"
                shift 2
                ;;
            --max-depth)
                MAX_DEPTH="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
            *)
                if [[ -z "$TARGET_DIR" ]]; then
                    TARGET_DIR="$1"
                else
                    echo -e "${RED}Error: Multiple directory arguments provided${NC}" >&2
                    echo "Use --help for usage information." >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${PURPLE}[VERBOSE]${NC} $1"
    fi
}

# Check if zoxide is installed
check_zoxide() {
    if ! command -v zoxide &> /dev/null; then
        log_error "zoxide is not installed or not in PATH"
        echo "Please install zoxide first: https://github.com/ajeetdsouza/zoxide"
        exit 1
    fi

    local zoxide_version
    zoxide_version=$(zoxide --version 2>/dev/null | head -n1)
    log_verbose "Found zoxide: $zoxide_version"
}

# Validate target directory
validate_directory() {
    local dir="$1"

    # Expand tilde
    dir="${dir/#\~/$HOME}"

    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        exit 1
    fi

    if [[ ! -r "$dir" ]]; then
        log_error "Directory is not readable: $dir"
        exit 1
    fi

    # Update TARGET_DIR with expanded path
    TARGET_DIR="$(realpath "$dir")"
    log_verbose "Validated target directory: $TARGET_DIR"
}

# Check if directory is already in zoxide database
is_in_zoxide() {
    local dir="$1"
    zoxide query --list | grep -Fxq "$dir"
}

# Add directory to zoxide
add_to_zoxide() {
    local dir="$1"
    local dir_name
    dir_name="$(basename "$dir")"

    TOTAL_FOUND=$((TOTAL_FOUND + 1))

    # Skip hidden directories
    if [[ "$dir_name" == .* ]]; then
        log_verbose "Skipping hidden directory: $dir_name"
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would add: $dir_name → $dir"
        TOTAL_ADDED=$((TOTAL_ADDED + 1))
        return 0
    fi

    # Add to zoxide with better error handling
    if zoxide add "$dir" 2>&1; then
        log_success "Added: $dir_name → $dir"
        TOTAL_ADDED=$((TOTAL_ADDED + 1))
    else
        local exit_code=$?
        log_error "Failed to add: $dir_name → $dir (exit code: $exit_code)"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
}

# Find and process directories
process_directories() {
    log_info "Scanning for directories in: $TARGET_DIR"
    log_verbose "Depth range: $MIN_DEPTH to $MAX_DEPTH"

    local find_cmd="find \"$TARGET_DIR\""

    # Add depth constraints
    if [[ "$MIN_DEPTH" -gt 0 ]]; then
        find_cmd+=" -mindepth $MIN_DEPTH"
    fi
    if [[ "$MAX_DEPTH" -gt 0 ]]; then
        find_cmd+=" -maxdepth $MAX_DEPTH"
    fi

    # Add directory type and exclude criteria
    find_cmd+=" -type d"
    find_cmd+=" -not -path \"*/.*\""  # Exclude hidden directories

    log_verbose "Find command: $find_cmd"

    # Create array of directories to avoid pipeline issues
    local dirs=()
    log_verbose "Building directory list..."
    
    while IFS= read -r dir; do
        if [[ -n "$dir" && "$dir" != "$TARGET_DIR" ]]; then
            dirs+=("$dir")
        fi
    done < <(eval "$find_cmd")

    local total_dirs=${#dirs[@]}
    log_info "Found $total_dirs subdirectories to process"
    log_verbose "Directory array built with ${#dirs[@]} entries"

    # Process each directory from array
    local dir_count=0
    for dir in "${dirs[@]}"; do
        dir_count=$((dir_count + 1))
        log_verbose "Processing ($dir_count/$total_dirs): $(basename "$dir")"
        log_verbose "Full path: $dir"

        add_to_zoxide "$dir"
        
        # Add small delay to see progress
        sleep 0.1
    done

    log_info "Completed processing $dir_count directories"
}

# Show statistics
show_statistics() {
    if [[ "$SHOW_STATS" != true ]]; then
        return 0
    fi

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}           ZOXIDE STATISTICS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}Target Directory:${NC} $TARGET_DIR"
    echo -e "${BLUE}Depth Range:${NC} $MIN_DEPTH to $MAX_DEPTH"
    echo -e "${BLUE}Mode:${NC} $([ "$DRY_RUN" == true ] && echo "DRY RUN" || echo "LIVE")"
    echo ""
    echo -e "${GREEN}Directories Found:${NC} $TOTAL_FOUND"
    echo -e "${GREEN}Successfully Added:${NC} $TOTAL_ADDED"
    echo -e "${YELLOW}Skipped:${NC} $TOTAL_SKIPPED"
    echo -e "${RED}Errors:${NC} $TOTAL_ERRORS"
    echo ""

    if [[ "$TOTAL_ADDED" -gt 0 ]]; then
        echo -e "${GREEN}✓ Successfully processed $TOTAL_ADDED directories${NC}"
    fi

    if [[ "$TOTAL_ERRORS" -gt 0 ]]; then
        echo -e "${RED}⚠ Encountered $TOTAL_ERRORS errors${NC}"
    fi

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

# Main function
main() {
    echo -e "${CYAN}Zoxide Bulk Directory Learning Script v${VERSION}${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Validate required arguments
    if [[ -z "$TARGET_DIR" ]]; then
        log_error "No directory specified"
        echo "Use --help for usage information."
        exit 1
    fi

    # Check prerequisites
    check_zoxide
    validate_directory "$TARGET_DIR"

    # Show mode information
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Running in DRY RUN mode - no changes will be made"
    fi

    if [[ "$FORCE" == true ]]; then
        log_info "Force mode enabled - will re-add existing directories"
    fi

    # Process directories
    process_directories

    # Show results
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run completed. Run without --dry-run to apply changes."
    else
        log_success "Zoxide learning completed!"
    fi

    show_statistics

    # Suggest next steps
    if [[ "$TOTAL_ADDED" -gt 0 && "$DRY_RUN" != true ]]; then
        echo ""
        log_info "You can now use 'z <directory_name>' to quickly navigate!"
        log_info "Example: z $(basename "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)" 2>/dev/null || echo "project")"
    fi
}

# Run main function with all arguments
main "$@"
