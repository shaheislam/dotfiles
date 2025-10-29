#!/usr/bin/env bash

# package-offline.sh - Create offline installation package for AWS workspaces
# Bundles dotfiles with pre-downloaded binaries for air-gapped installation

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/dotfiles-offline"
OUTPUT_FILE="$HOME/dotfiles-offline.tar.gz"

# Binary versions
STARSHIP_VERSION="latest"
EZA_VERSION="latest"
ZOXIDE_VERSION="latest"
BAT_VERSION="latest"
RIPGREP_VERSION="latest"
FD_VERSION="latest"

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}\n"
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

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# ============================================================================
# Download Binaries
# ============================================================================

download_starship() {
    print_step "Downloading Starship..."

    local url="https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz"
    local dest="$PACKAGE_DIR/binaries"

    mkdir -p "$dest"

    if curl -L "$url" | tar xz -C "$dest" 2>/dev/null; then
        print_success "Starship downloaded"
    else
        print_warning "Failed to download Starship"
    fi
}

download_eza() {
    print_step "Downloading eza..."

    local url="https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
    local dest="$PACKAGE_DIR/binaries"

    mkdir -p "$dest"

    if curl -L "$url" | tar xz -C "$dest" 2>/dev/null; then
        print_success "eza downloaded"
    else
        print_warning "Failed to download eza"
    fi
}

download_zoxide() {
    print_step "Downloading zoxide..."

    local url="https://github.com/ajeetdsouza/zoxide/releases/latest/download/zoxide-x86_64-unknown-linux-musl.tar.gz"
    local dest="$PACKAGE_DIR/binaries"

    mkdir -p "$dest"

    if curl -L "$url" | tar xz -C "$dest" 2>/dev/null; then
        print_success "zoxide downloaded"
    else
        print_warning "Failed to download zoxide"
    fi
}

download_bat() {
    print_step "Downloading bat..."

    # Get latest release
    local latest_tag=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

    if [[ -z "$latest_tag" ]]; then
        print_warning "Failed to get bat version"
        return
    fi

    local url="https://github.com/sharkdp/bat/releases/download/v${latest_tag}/bat-v${latest_tag}-x86_64-unknown-linux-gnu.tar.gz"
    local dest="$PACKAGE_DIR/binaries"

    mkdir -p "$dest"

    if curl -L "$url" -o "$dest/bat.tar.gz" 2>/dev/null; then
        tar xzf "$dest/bat.tar.gz" -C "$dest" --strip-components=1 "bat-v${latest_tag}-x86_64-unknown-linux-gnu/bat"
        rm "$dest/bat.tar.gz"
        print_success "bat downloaded"
    else
        print_warning "Failed to download bat"
    fi
}

download_ripgrep() {
    print_step "Downloading ripgrep..."

    local latest_tag=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ -z "$latest_tag" ]]; then
        print_warning "Failed to get ripgrep version"
        return
    fi

    local url="https://github.com/BurntSushi/ripgrep/releases/download/${latest_tag}/ripgrep-${latest_tag}-x86_64-unknown-linux-musl.tar.gz"
    local dest="$PACKAGE_DIR/binaries"

    mkdir -p "$dest"

    if curl -L "$url" -o "$dest/rg.tar.gz" 2>/dev/null; then
        tar xzf "$dest/rg.tar.gz" -C "$dest" --strip-components=1 "ripgrep-${latest_tag}-x86_64-unknown-linux-musl/rg"
        rm "$dest/rg.tar.gz"
        print_success "ripgrep downloaded"
    else
        print_warning "Failed to download ripgrep"
    fi
}

download_fd() {
    print_step "Downloading fd..."

    local latest_tag=$(curl -s https://api.github.com/repos/sharkdp/fd/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

    if [[ -z "$latest_tag" ]]; then
        print_warning "Failed to get fd version"
        return
    fi

    local url="https://github.com/sharkdp/fd/releases/download/v${latest_tag}/fd-v${latest_tag}-x86_64-unknown-linux-gnu.tar.gz"
    local dest="$PACKAGE_DIR/binaries"

    mkdir -p "$dest"

    if curl -L "$url" -o "$dest/fd.tar.gz" 2>/dev/null; then
        tar xzf "$dest/fd.tar.gz" -C "$dest" --strip-components=1 "fd-v${latest_tag}-x86_64-unknown-linux-gnu/fd"
        rm "$dest/fd.tar.gz"
        print_success "fd downloaded"
    else
        print_warning "Failed to download fd"
    fi
}

download_all_binaries() {
    print_header "Downloading Portable Binaries"

    download_starship
    download_eza
    download_zoxide
    download_bat
    download_ripgrep
    download_fd

    # Make all binaries executable
    chmod +x "$PACKAGE_DIR/binaries"/* 2>/dev/null || true

    print_success "Binary downloads complete"
}

# ============================================================================
# Copy Dotfiles
# ============================================================================

copy_dotfiles() {
    print_header "Copying Dotfiles"

    print_step "Copying dotfiles repository..."

    # Copy entire dotfiles directory
    cp -r "$DOTFILES_ROOT" "$PACKAGE_DIR/dotfiles"

    # Remove git directories to save space
    find "$PACKAGE_DIR/dotfiles" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

    # Remove unnecessary files
    rm -rf "$PACKAGE_DIR/dotfiles/.github" 2>/dev/null || true
    rm -rf "$PACKAGE_DIR/dotfiles/homebrew" 2>/dev/null || true  # macOS specific

    print_success "Dotfiles copied"
}

# ============================================================================
# Create Install Script
# ============================================================================

create_install_script() {
    print_step "Creating offline installer..."

    # Copy the offline installer
    if [[ -f "$SCRIPT_DIR/install-offline.sh" ]]; then
        cp "$SCRIPT_DIR/install-offline.sh" "$PACKAGE_DIR/install.sh"
        chmod +x "$PACKAGE_DIR/install.sh"
        print_success "Installer script added"
    else
        print_warning "install-offline.sh not found, creating basic installer"

        cat > "$PACKAGE_DIR/install.sh" << 'EOF'
#!/usr/bin/env bash
# Basic offline installer

set -euo pipefail

echo "Installing dotfiles..."

# Install binaries
mkdir -p ~/.local/bin
cp binaries/* ~/.local/bin/ 2>/dev/null || true

# Install dotfiles
cd dotfiles
if command -v stow &> /dev/null; then
    stow . --adopt --verbose
else
    echo "Warning: stow not found, manually symlinking..."
    # Manual symlinking fallback
    for file in .??*; do
        [[ -e ~/$file ]] && mv ~/$file ~/${file}.backup
        ln -s "$(pwd)/$file" ~/
    done
fi

echo "Installation complete!"
echo "Add ~/.local/bin to your PATH if not already there"
EOF
        chmod +x "$PACKAGE_DIR/install.sh"
    fi
}

# ============================================================================
# Create README
# ============================================================================

create_readme() {
    print_step "Creating README..."

    cat > "$PACKAGE_DIR/README.txt" << 'EOF'
Dotfiles Offline Installation Package
=====================================

This package contains:
- Dotfiles configuration
- Pre-downloaded binaries for common tools
- Offline installer script

Installation:
-------------

1. Extract this package:
   tar xzf dotfiles-offline.tar.gz
   cd dotfiles-offline

2. Run the installer:
   ./install.sh

3. Add binaries to PATH:
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc

What's Included:
----------------
- Dotfiles (Fish, Zsh, tmux, Neovim configs)
- Binaries: starship, eza, zoxide, bat, ripgrep, fd
- Installation script

Requirements:
-------------
- Bash
- tar, gzip (for extraction)
- Optional: stow (for better dotfile management)

For more information, see:
https://github.com/shaheislam/dotfiles

EOF

    print_success "README created"
}

# ============================================================================
# Create Tarball
# ============================================================================

create_tarball() {
    print_header "Creating Tarball"

    print_step "Compressing package..."

    cd "$TEMP_DIR"

    if tar czf "$OUTPUT_FILE" dotfiles-offline/; then
        local size=$(du -h "$OUTPUT_FILE" | cut -f1)
        print_success "Package created: $OUTPUT_FILE ($size)"
    else
        print_error "Failed to create tarball"
        return 1
    fi
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    print_header "Dotfiles Offline Package Creator"

    echo "This script will create a portable installation package"
    echo "for air-gapped AWS workspaces."
    echo ""
    echo "Package will include:"
    echo "  - Complete dotfiles repository"
    echo "  - Pre-downloaded binaries (starship, eza, zoxide, etc.)"
    echo "  - Offline installer script"
    echo ""
    echo "Output: $OUTPUT_FILE"
    echo ""

    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not found"
        exit 1
    fi

    if ! command -v tar &> /dev/null; then
        print_error "tar is required but not found"
        exit 1
    fi

    # Create package directory
    mkdir -p "$PACKAGE_DIR"

    # Download binaries
    download_all_binaries

    # Copy dotfiles
    copy_dotfiles

    # Create installer
    create_install_script

    # Create README
    create_readme

    # Create tarball
    create_tarball

    # Summary
    print_header "Package Complete!"

    echo "Package created successfully!"
    echo ""
    echo "Location: $OUTPUT_FILE"
    echo "Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo ""
    echo "Next steps:"
    echo "  1. Transfer this file to your AWS workspace"
    echo "  2. Extract: tar xzf dotfiles-offline.tar.gz"
    echo "  3. Install: cd dotfiles-offline && ./install.sh"
    echo ""
    echo "See OFFLINE-INSTALL.md for transfer methods"
}

# Run main function
main "$@"
