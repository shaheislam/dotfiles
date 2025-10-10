#!/usr/bin/env bash
# setup-git-local-excludes.sh
# Sets up local git excludes with convenient symlinks for all repos in a directory
# Safe to run multiple times - won't overwrite existing configurations

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_DIR=""
DRY_RUN=false
FORCE_MODE=false
ADD_PATTERNS=()
VERBOSE=false

# Counters
REPOS_PROCESSED=0
REPOS_UPDATED=0
REPOS_SKIPPED=0
REPOS_FAILED=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            echo -e "${YELLOW}Running in DRY RUN mode - no changes will be made${NC}"
            shift
            ;;
        --force)
            FORCE_MODE=true
            echo -e "${YELLOW}Running in FORCE mode - existing exclude files will be overwritten${NC}"
            shift
            ;;
        --add-pattern)
            ADD_PATTERNS+=("$2")
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [directory] [options]"
            echo ""
            echo "Sets up .git/info/exclude with .gitignore_local symlinks for all git repos"
            echo ""
            echo "Arguments:"
            echo "  directory          Directory to search for git repos (default: ~/work)"
            echo ""
            echo "Options:"
            echo "  --dry-run          Show what would be done without making changes"
            echo "  --force            Overwrite existing exclude files with template"
            echo "  --add-pattern PAT  Add custom pattern to all exclude files"
            echo "  --verbose, -v      Show detailed output"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Process all repos in ~/work"
            echo "  $0 ~/projects                # Process all repos in ~/projects"
            echo "  $0 --dry-run                 # See what would be done"
            echo "  $0 --force                   # Overwrite existing exclude files"
            echo "  $0 --add-pattern '*.local'   # Add pattern to all repos"
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            if [[ -z "$DEFAULT_DIR" ]]; then
                DEFAULT_DIR="$1"
            else
                echo -e "${RED}Error: Multiple directories specified${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default directory if not specified
if [[ -z "$DEFAULT_DIR" ]]; then
    DEFAULT_DIR="$HOME/work"
fi

# Default patterns to add to exclude files
DEFAULT_EXCLUDES=(
    ".gitignore_local"
    "*.local"
    ".env.local"
    ".vscode/"
    ".idea/"
    ".claude/"
    ".codex/"
    ".DS_Store"
    "*.swp"
    "*.swo"
    "*~"
    ".pyrightconfig.json"
    ".eslintrc.local.json"
    "tsconfig.local.json"
)

# Function to log verbose messages
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Function to extract custom patterns from existing exclude file
extract_custom_patterns() {
    local exclude_file="$1"
    local -a custom_patterns=()

    if [[ -f "$exclude_file" ]]; then
        # Read all non-comment, non-empty lines
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue

            # Check if this pattern is NOT in our defaults
            local is_custom=true
            for default_pattern in "${DEFAULT_EXCLUDES[@]}"; do
                if [[ "$line" == "$default_pattern" ]]; then
                    is_custom=false
                    break
                fi
            done

            # If it's custom and not already in our list, add it
            if [[ "$is_custom" == true ]]; then
                local already_added=false
                for existing in "${custom_patterns[@]}"; do
                    if [[ "$existing" == "$line" ]]; then
                        already_added=true
                        break
                    fi
                done
                if [[ "$already_added" == false ]]; then
                    custom_patterns+=("$line")
                fi
            fi
        done < "$exclude_file"
    fi

    # Return the array by printing each element
    printf '%s\n' "${custom_patterns[@]}"
}

# Function to setup exclude file for a single repo
setup_repo_exclude() {
    local repo_dir="$1"
    local git_dir="$repo_dir/.git"
    local exclude_file="$git_dir/info/exclude"
    local gitignore_local="$repo_dir/.gitignore_local"
    local repo_name=$(basename "$repo_dir")

    echo -e "\n${BLUE}Processing:${NC} $repo_name"

    # Check if it's a git repository
    if [[ ! -d "$git_dir" ]]; then
        echo -e "${YELLOW}  ⚠ Not a git repository, skipping${NC}"
        ((REPOS_SKIPPED++))
        return
    fi

    # Create info directory if it doesn't exist
    if [[ ! -d "$git_dir/info" ]]; then
        log_verbose "  Creating $git_dir/info directory"
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$git_dir/info"
        fi
    fi

    # Check if exclude file exists and has content
    local exclude_exists=false
    local has_gitignore_local=false
    if [[ -f "$exclude_file" ]]; then
        exclude_exists=true
        if grep -q "^\.gitignore_local$" "$exclude_file" 2>/dev/null; then
            has_gitignore_local=true
        fi
    fi

    # Check if symlink already exists
    local symlink_exists=false
    local symlink_correct=false
    if [[ -e "$gitignore_local" || -L "$gitignore_local" ]]; then
        symlink_exists=true
        if [[ -L "$gitignore_local" ]]; then
            local target=$(readlink "$gitignore_local")
            if [[ "$target" == ".git/info/exclude" ]]; then
                symlink_correct=true
            fi
        fi
    fi

    # Determine what needs to be done
    local needs_update=false
    local actions=()

    if [[ "$FORCE_MODE" == true ]] && [[ "$exclude_exists" == true ]]; then
        actions+=("Force overwrite exclude file with template")
        needs_update=true
    elif [[ "$exclude_exists" == false ]]; then
        actions+=("Create exclude file")
        needs_update=true
    elif [[ "$exclude_exists" == true ]] && [[ "$FORCE_MODE" == false ]]; then
        # Check if any patterns are missing or if we have custom patterns to preserve
        local has_missing=false
        for pattern in "${DEFAULT_EXCLUDES[@]}"; do
            if ! grep -qF "$pattern" "$exclude_file" 2>/dev/null; then
                has_missing=true
                break
            fi
        done

        # Extract custom patterns to see if we need to reorganize
        mapfile -t TEMP_CUSTOM < <(extract_custom_patterns "$exclude_file")

        if [[ "$has_missing" == true ]] || [[ ${#TEMP_CUSTOM[@]} -gt 0 ]]; then
            actions+=("Smart merge: ensure all defaults + preserve custom patterns")
            needs_update=true
        fi
    fi

    if [[ "$symlink_exists" == false ]]; then
        actions+=("Create .gitignore_local symlink")
        needs_update=true
    elif [[ "$symlink_correct" == false ]]; then
        actions+=("Fix .gitignore_local symlink")
        needs_update=true
    fi

    # Report status
    if [[ "$needs_update" == false ]]; then
        echo -e "${GREEN}  ✓ Already configured${NC}"
        ((REPOS_SKIPPED++))
        return
    fi

    # Show what will be done
    if [[ ${#actions[@]} -gt 0 ]]; then
        echo -e "${YELLOW}  Actions needed:${NC}"
        for action in "${actions[@]}"; do
            echo "    - $action"
        done
    fi

    if [[ "$DRY_RUN" == true ]]; then
        ((REPOS_PROCESSED++))
        return
    fi

    # Perform the setup
    echo -e "${GREEN}  Applying changes...${NC}"

    # Create or update exclude file
    if [[ "$FORCE_MODE" == true ]] || [[ "$exclude_exists" == false ]]; then
        if [[ "$FORCE_MODE" == true ]] && [[ "$exclude_exists" == true ]]; then
            log_verbose "  Force mode: Overwriting existing exclude file"
        else
            log_verbose "  Creating new exclude file"
        fi
        cat > "$exclude_file" << 'EOF'
# Local git excludes - patterns that won't be committed
# This file is symlinked to .gitignore_local for easy editing

EOF
        # Add all default patterns
        for pattern in "${DEFAULT_EXCLUDES[@]}"; do
            echo "$pattern" >> "$exclude_file"
        done
        # Add any custom patterns from command line
        for pattern in "${ADD_PATTERNS[@]}"; do
            echo "$pattern" >> "$exclude_file"
        done
    else
        # Smart merge mode (non-force): preserve custom patterns while ensuring all defaults
        log_verbose "  Smart merge: Preserving custom patterns while ensuring defaults"

        # Extract existing custom patterns
        mapfile -t CUSTOM_PATTERNS < <(extract_custom_patterns "$exclude_file")

        # Rewrite the file with clean structure
        cat > "$exclude_file" << 'EOF'
# Local git excludes - patterns that won't be committed
# This file is symlinked to .gitignore_local for easy editing

EOF
        # Add all default patterns
        echo "# Standard excludes" >> "$exclude_file"
        for pattern in "${DEFAULT_EXCLUDES[@]}"; do
            echo "$pattern" >> "$exclude_file"
        done

        # Add command-line patterns if any
        if [[ ${#ADD_PATTERNS[@]} -gt 0 ]]; then
            echo "" >> "$exclude_file"
            echo "# Added via command line" >> "$exclude_file"
            for pattern in "${ADD_PATTERNS[@]}"; do
                # Only add if not already in defaults
                local is_duplicate=false
                for default in "${DEFAULT_EXCLUDES[@]}"; do
                    if [[ "$pattern" == "$default" ]]; then
                        is_duplicate=true
                        break
                    fi
                done
                if [[ "$is_duplicate" == false ]]; then
                    echo "$pattern" >> "$exclude_file"
                fi
            done
        fi

        # Add preserved custom patterns
        if [[ ${#CUSTOM_PATTERNS[@]} -gt 0 ]]; then
            echo "" >> "$exclude_file"
            echo "# Custom patterns (preserved)" >> "$exclude_file"
            for pattern in "${CUSTOM_PATTERNS[@]}"; do
                # Skip if it's in ADD_PATTERNS (to avoid duplicates)
                local is_duplicate=false
                for added in "${ADD_PATTERNS[@]}"; do
                    if [[ "$pattern" == "$added" ]]; then
                        is_duplicate=true
                        break
                    fi
                done
                if [[ "$is_duplicate" == false ]]; then
                    echo "$pattern" >> "$exclude_file"
                fi
            done
        fi
    fi

    # Create or fix symlink
    if [[ "$symlink_exists" == false ]]; then
        log_verbose "  Creating symlink .gitignore_local -> .git/info/exclude"
        (cd "$repo_dir" && ln -s .git/info/exclude .gitignore_local)
    elif [[ "$symlink_correct" == false ]]; then
        log_verbose "  Fixing symlink .gitignore_local"
        rm -f "$gitignore_local"
        (cd "$repo_dir" && ln -s .git/info/exclude .gitignore_local)
    fi

    echo -e "${GREEN}  ✓ Setup complete${NC}"
    ((REPOS_UPDATED++))
    ((REPOS_PROCESSED++))
}

# Main execution
echo -e "${BLUE}=== Git Local Exclude Setup ===${NC}"
echo -e "Target directory: ${GREEN}$DEFAULT_DIR${NC}"
echo ""

# Check if directory exists
if [[ ! -d "$DEFAULT_DIR" ]]; then
    echo -e "${RED}Error: Directory '$DEFAULT_DIR' does not exist${NC}"
    exit 1
fi

# Find all git repositories
echo -e "${BLUE}Searching for git repositories...${NC}"
mapfile -t GIT_REPOS < <(find "$DEFAULT_DIR" -maxdepth 2 -type d -name ".git" 2>/dev/null | sed 's/\/.git$//' | sort)

if [[ ${#GIT_REPOS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No git repositories found in $DEFAULT_DIR${NC}"
    exit 0
fi

echo -e "Found ${GREEN}${#GIT_REPOS[@]}${NC} repositories"

# Debug: Show first few repos
if [[ "$VERBOSE" == true ]]; then
    echo "Debug: First 3 repos: ${GIT_REPOS[0]}, ${GIT_REPOS[1]}, ${GIT_REPOS[2]}"
fi

# Process each repository
for repo in "${GIT_REPOS[@]}"; do
    setup_repo_exclude "$repo" || ((REPOS_FAILED++))
done

# Summary
echo -e "\n${BLUE}=== Summary ===${NC}"
echo -e "Repositories processed: ${GREEN}$REPOS_PROCESSED${NC}"
echo -e "Repositories updated:   ${GREEN}$REPOS_UPDATED${NC}"
echo -e "Repositories skipped:   ${YELLOW}$REPOS_SKIPPED${NC}"
if [[ $REPOS_FAILED -gt 0 ]]; then
    echo -e "Repositories failed:    ${RED}$REPOS_FAILED${NC}"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo -e "\n${YELLOW}This was a dry run - no changes were made${NC}"
    echo -e "Run without --dry-run to apply changes"
fi

echo -e "\n${GREEN}Done!${NC}"
exit 0