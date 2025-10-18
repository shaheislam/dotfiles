#!/usr/bin/env bash
# Nix LSP management - Part of the hybrid approach
# Combines global baseline with project-specific overrides

set -e

echo "=== Nix LSP Hybrid Setup ==="
echo ""

# Option 1: Hybrid setup (recommended)
if [ "$1" = "hybrid" ] || [ -z "$1" ]; then
    echo "Setting up hybrid LSP configuration..."
    echo ""
    echo "This approach gives you:"
    echo "  • Global baseline LSPs (always available)"
    echo "  • Project-specific overrides (via direnv)"
    echo ""

    # Check if direnv is installed
    if ! command -v direnv &> /dev/null; then
        echo "⚠️  direnv not found. Installing with Homebrew..."
        brew install direnv
        echo "✓ direnv installed"
    fi

    echo "Step 1: Installing global baseline LSPs..."
    echo "----------------------------------------"
    if [ -f ~/dotfiles/scripts/install-lsps-global.sh ]; then
        read -p "Install global LSPs now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ~/dotfiles/scripts/install-lsps-global.sh
        else
            echo "Skipped. Run './scripts/install-lsps-global.sh' later."
        fi
    fi

    echo ""
    echo "Step 2: Setting up direnv for overrides..."
    echo "----------------------------------------"

    # Setup direnv hook if not already configured
    if ! grep -q "direnv hook" ~/.config/fish/config.fish 2>/dev/null; then
        echo "Adding direnv to Fish shell..."
        echo 'eval (direnv hook fish)' >> ~/.config/fish/config.fish
        echo "✓ direnv hook added to Fish"
    fi

    if ! grep -q "direnv hook" ~/.zshrc 2>/dev/null; then
        echo "Adding direnv to Zsh..."
        echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
        echo "✓ direnv hook added to Zsh"
    fi

    echo ""
    echo "✅ Hybrid setup complete!"
    echo ""
    echo "📝 How it works:"
    echo "   1. Global LSPs are always available (baseline)"
    echo "   2. Project .envrc files can override with specific versions"
    echo "   3. PATH precedence: project > global"
    echo ""
    echo "📁 To override LSPs in a project:"
    echo "   cd your-project"
    echo "   echo 'use flake' > .envrc"
    echo "   # Edit flake.nix to specify LSP versions"
    echo "   direnv allow"
    echo ""
    exit 0
fi

# Option 2: Enter a Nix shell with all LSPs
if [ "$1" = "shell" ]; then
    echo "Entering Nix development shell..."
    echo "All LSPs from global profile will be available in this shell."
    cd ~/dotfiles
    exec nix develop nix/global
fi

# Option 3: Use direnv only (no global baseline)
if [ "$1" = "direnv-only" ]; then
    echo "Setting up direnv-only LSP loading..."

    if ! command -v direnv &> /dev/null; then
        echo "Error: direnv is not installed. Install with: brew install direnv"
        exit 1
    fi

    cd ~/dotfiles
    echo 'use flake ./nix/global' > .envrc
    direnv allow

    echo ""
    echo "✓ direnv configured!"
    echo ""
    echo "LSPs will now automatically load when you enter ~/dotfiles"
    echo "To use LSPs in other projects, create a .envrc file with:"
    echo "  use flake ~/dotfiles/nix/global"
    echo ""
    exit 0
fi

# Option 3: Build and activate the profile
if [ "$1" = "build" ]; then
    echo "Building Nix global profile..."
    cd ~/dotfiles/nix/global
    nix build
    echo ""
    echo "✓ Profile built successfully!"
    echo ""
    echo "To use the LSPs, run one of:"
    echo "  nix develop ~/dotfiles/nix/global  # Enter shell with LSPs"
    echo "  ./activate-nix-lsps.sh direnv      # Setup automatic loading"
    echo ""
    exit 0
fi

# Show usage
echo "Usage: $0 [hybrid|shell|direnv-only|build]"
echo ""
echo "Options:"
echo "  hybrid       - Set up global baseline + direnv overrides (RECOMMENDED)"
echo "  shell        - Enter a Nix shell with all LSPs available"
echo "  direnv-only  - Use direnv without global baseline"
echo "  build        - Build the Nix global profile"
echo ""
echo "🚀 Quick start:"
echo "  $0          # Same as 'hybrid' - the recommended setup"
echo "  $0 hybrid   # Explicitly run hybrid setup"
echo ""
echo "📦 The global profile includes:"
echo "  • Go (gopls), Python (pyright/basedpyright), Rust (rust-analyzer)"
echo "  • TypeScript, Terraform, Docker, Ansible, Helm"
echo "  • YAML, JSON, TOML, Markdown, Bash, SQL, Nix"
echo "  • And more..."
echo ""
echo "🔄 Hybrid approach benefits:"
echo "  • Always have LSPs available (global baseline)"
echo "  • Override per-project when needed (direnv)"
echo "  • Best of both worlds!"