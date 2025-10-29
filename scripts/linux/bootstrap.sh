#!/usr/bin/env bash

# bootstrap.sh - Single-command dotfiles installer for AWS Linux workspaces
# Usage: curl -fsSL <raw-url>/bootstrap.sh | bash
# Or: curl -fsSL <raw-url>/bootstrap.sh | bash -s -- --minimal --dry-run

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Repository configuration
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/shaheislam/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Utility Functions
# ============================================================================

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ____        __  _____ __
   / __ \____  / /_/ __(_) /__  _____
  / / / / __ \/ __/ /_/ / / _ \/ ___/
 / /_/ / /_/ / /_/ __/ / /  __(__  )
/_____/\____/\__/_/ /_/_/\___/____/

  AWS Linux Workspace Bootstrap
EOF
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ============================================================================
# Prerequisite Checks
# ============================================================================

check_prerequisites() {
    local missing_deps=()

    # Check for required commands
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing_deps+=("curl or wget")
    fi

    if ! command -v bash &> /dev/null; then
        missing_deps+=("bash")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install missing dependencies:"
        echo ""
        echo "  # Amazon Linux / RHEL / CentOS"
        echo "  sudo yum install -y git curl"
        echo ""
        echo "  # Ubuntu / Debian"
        echo "  sudo apt-get update && sudo apt-get install -y git curl"
        echo ""
        return 1
    fi

    print_success "All prerequisites satisfied"
    return 0
}

# ============================================================================
# Repository Management
# ============================================================================

clone_or_update_dotfiles() {
    print_step "Setting up dotfiles repository..."

    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        print_warning "Dotfiles directory already exists at $DOTFILES_DIR"

        # Ask user if they want to update
        echo -e "${YELLOW}Update existing repository? (y/n)${NC}"
        read -r -n 1 response
        echo ""

        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_step "Updating existing repository..."
            cd "$DOTFILES_DIR"

            # Stash any local changes
            if ! git diff-index --quiet HEAD --; then
                print_warning "Stashing local changes..."
                git stash
            fi

            # Pull latest changes
            git fetch origin
            git checkout "$DOTFILES_BRANCH"
            git pull origin "$DOTFILES_BRANCH"

            print_success "Repository updated"
        else
            print_warning "Using existing repository without updating"
        fi
    else
        # Remove directory if it exists but is not a git repo
        if [[ -d "$DOTFILES_DIR" ]]; then
            print_warning "Removing non-git directory at $DOTFILES_DIR"
            rm -rf "$DOTFILES_DIR"
        fi

        # Clone the repository
        print_step "Cloning dotfiles repository..."
        if git clone --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$DOTFILES_DIR"; then
            print_success "Repository cloned successfully"
        else
            print_error "Failed to clone repository"
            echo ""
            echo "Please check:"
            echo "  1. Repository URL is correct: $DOTFILES_REPO"
            echo "  2. You have access to the repository"
            echo "  3. Network connectivity is working"
            echo ""
            echo "You can override the repository URL:"
            echo "  DOTFILES_REPO=<your-repo-url> curl ... | bash"
            return 1
        fi
    fi
}

# ============================================================================
# Setup Script Execution
# ============================================================================

run_setup_script() {
    local setup_script="$DOTFILES_DIR/scripts/linux/setup-aws-workspace.sh"

    if [[ ! -f "$setup_script" ]]; then
        print_error "Setup script not found: $setup_script"
        echo ""
        echo "The repository might be using a different structure."
        echo "Please run the setup script manually."
        return 1
    fi

    # Make script executable
    chmod +x "$setup_script"

    print_step "Running setup script..."
    echo ""

    # Pass all arguments to the setup script
    if bash "$setup_script" "$@"; then
        print_success "Setup completed successfully!"
        return 0
    else
        print_error "Setup script failed"
        echo ""
        echo "You can try running the setup script manually:"
        echo "  cd $DOTFILES_DIR/scripts/linux"
        echo "  ./setup-aws-workspace.sh --help"
        return 1
    fi
}

# ============================================================================
# Help Function
# ============================================================================

show_help() {
    cat << EOF
Dotfiles Bootstrap Installer

USAGE:
    curl -fsSL <raw-url>/bootstrap.sh | bash
    curl -fsSL <raw-url>/bootstrap.sh | bash -s -- [OPTIONS]

OPTIONS:
    --minimal           Install only core tools
    --dry-run           Preview without installing
    --skip-neovim       Skip Neovim setup
    --skip-shells       Skip Fish/Zsh setup
    --skip-stow         Skip dotfiles symlinking
    --verbose           Show detailed output
    -h, --help          Show this help (run locally)

ENVIRONMENT VARIABLES:
    DOTFILES_REPO       Repository URL (default: https://github.com/shaheislam/dotfiles.git)
    DOTFILES_DIR        Installation directory (default: ~/dotfiles)
    DOTFILES_BRANCH     Git branch to use (default: main)

EXAMPLES:
    # Full setup
    curl -fsSL <raw-url>/bootstrap.sh | bash

    # Minimal setup
    curl -fsSL <raw-url>/bootstrap.sh | bash -s -- --minimal

    # Custom repository
    DOTFILES_REPO=https://github.com/myuser/mydotfiles.git curl -fsSL <raw-url>/bootstrap.sh | bash

    # Dry run to preview
    curl -fsSL <raw-url>/bootstrap.sh | bash -s -- --dry-run

WHAT THIS DOES:
    1. Checks prerequisites (git, curl, bash)
    2. Clones dotfiles repository to ~/dotfiles
    3. Runs setup-aws-workspace.sh with your flags
    4. Sets up complete development environment

For more information, visit: https://github.com/shaheislam/dotfiles

EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    # Check for help flag
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    # Print banner
    print_banner

    echo "This script will:"
    echo "  1. Check prerequisites"
    echo "  2. Clone/update dotfiles repository"
    echo "  3. Run the full setup script"
    echo ""
    echo "Repository: $DOTFILES_REPO"
    echo "Install to: $DOTFILES_DIR"
    echo "Branch: $DOTFILES_BRANCH"
    echo ""

    # Ask for confirmation unless in CI/automated environment
    if [[ -t 0 ]]; then
        echo -e "${YELLOW}Continue? (y/n)${NC}"
        read -r -n 1 response
        echo ""

        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_warning "Installation cancelled"
            exit 0
        fi
    fi

    # Check prerequisites
    print_step "Checking prerequisites..."
    if ! check_prerequisites; then
        exit 1
    fi

    # Clone or update repository
    if ! clone_or_update_dotfiles; then
        exit 1
    fi

    # Run setup script with all passed arguments
    if ! run_setup_script "$@"; then
        exit 1
    fi

    # Final message
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Bootstrap Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Log out and back in for shell changes"
    echo "  2. Run 'tmux' then press Ctrl-s + I to install plugins"
    echo "  3. Run 'nvim' to complete Neovim setup"
    echo ""
    echo "For more information:"
    echo "  cat $DOTFILES_DIR/scripts/linux/README.md"
    echo ""
}

# ============================================================================
# Error Handling
# ============================================================================

# Set up error handler
trap 'print_error "Installation failed at line $LINENO"' ERR

# Run main function with all arguments
main "$@"
