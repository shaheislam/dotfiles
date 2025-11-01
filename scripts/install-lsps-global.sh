#!/usr/bin/env bash
# Install LSPs globally via nix-env as a baseline
# Part of the hybrid approach: Global base + project-specific overrides via direnv

set -e

echo "=== Nix LSP Hybrid Setup - Global Baseline Installation ==="
echo ""
echo "This installs LSPs globally as your baseline/fallback."
echo "Project-specific versions can override these using direnv."
echo ""
echo "Installing LSPs globally via nix-env..."
echo ""

# Function to try installing a package and report status
install_lsp() {
    local package=$1
    local name=$2
    echo -n "Installing $name... "

    if nix-env -iA "nixpkgs.$package" 2>/dev/null; then
        echo "✓"
    else
        echo "✗ (not available or already installed)"
    fi
}

echo "=== Language Servers ==="

# Go
install_lsp "gopls" "Go LSP (gopls)"
install_lsp "golangci-lint" "Go Linter"
install_lsp "delve" "Go Debugger"

# Python
echo -n "Installing Python LSP... "
# Try basedpyright first, fall back to pyright
if nix-env -iA nixpkgs.basedpyright 2>/dev/null; then
    echo "✓ (basedpyright)"
elif nix-env -iA nixpkgs.nodePackages.pyright 2>/dev/null; then
    echo "✓ (pyright)"
else
    echo "✗"
fi
install_lsp "ruff-lsp" "Python Ruff LSP"
install_lsp "python3Packages.debugpy" "Python Debugger"

# Rust
install_lsp "rust-analyzer" "Rust Analyzer"

# TypeScript/JavaScript
install_lsp "nodePackages.typescript-language-server" "TypeScript LSP"
install_lsp "nodePackages.vscode-langservers-extracted" "ESLint/JSON/HTML LSPs"

# Terraform
install_lsp "terraform-ls" "Terraform LSP"
install_lsp "tflint" "Terraform Linter"

# Shell
install_lsp "nodePackages.bash-language-server" "Bash LSP"
install_lsp "shellcheck" "Shell Checker"

# Docker
install_lsp "dockerfile-language-server-nodejs" "Dockerfile LSP"
install_lsp "nodePackages.dockerfile-language-server-nodejs" "Docker Compose LSP"
install_lsp "hadolint" "Dockerfile Linter"

# YAML
install_lsp "yaml-language-server" "YAML LSP"
install_lsp "yamllint" "YAML Linter"

# Ansible
# Note: ansible-language-server was removed from nixpkgs (unmaintained)
# install_lsp "ansible-language-server" "Ansible LSP"
install_lsp "ansible-lint" "Ansible Linter"

# Helm
install_lsp "helm-ls" "Helm LSP"

# Lua
install_lsp "lua-language-server" "Lua LSP"

# Markdown
install_lsp "marksman" "Markdown LSP"
install_lsp "markdownlint-cli" "Markdown Linter"

# SQL
install_lsp "sqls" "SQL LSP"

# Nix
install_lsp "nil" "Nix LSP"
install_lsp "nixpkgs-fmt" "Nix Formatter"
install_lsp "statix" "Nix Linter"

# TOML
install_lsp "taplo" "TOML LSP"

# Java
install_lsp "jdt-language-server" "Java LSP"

# C/C++
install_lsp "clang-tools" "C/C++ LSP (clangd)"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "✅ Global baseline LSPs are now installed."
echo ""
echo "📍 Current setup:"
echo "   • Global LSPs: Always available as fallback"
echo "   • Project overrides: Use direnv + flake.nix for specific versions"
echo ""
echo "🔍 To check what's installed:"
echo "   which gopls                  # Check specific LSP"
echo "   nix-env -q | grep -i lsp     # List installed LSPs"
echo ""
echo "📁 To override in a project:"
echo "   cd your-project"
echo "   echo 'use flake' > .envrc    # Create direnv file"
echo "   direnv allow                  # Activate overrides"
echo ""
echo "🔧 In Neovim:"
echo "   <leader>nl - List available LSPs"
echo "   <leader>nf - List available formatters"
echo "   <leader>ns - Show active LSP status"
echo ""
echo "Note: Some LSPs might not be available in nixpkgs."
echo "      PowerShell LSP is not currently packaged."