#!/bin/bash
#
# Setup script for Obsidian Vault Semantic Search
#
# This creates a dedicated venv, installs dependencies, and builds the initial index.
# Run once after cloning dotfiles, or when setting up a new machine.
#
# Usage: ./setup-vault-search.sh [vault_path]
#

set -e

VAULT_PATH="${1:-$HOME/obsidian}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$DOTFILES_DIR/.venv/vault-search"

echo "=== Obsidian Vault Semantic Search Setup ==="
echo ""

# Find a suitable Python 3.8+
PYTHON_CMD=""
for cmd in /Library/Frameworks/Python.framework/Versions/3.12/bin/python3 \
           /Library/Frameworks/Python.framework/Versions/3.11/bin/python3 \
           /opt/homebrew/bin/python3 \
           /usr/local/bin/python3 \
           python3; do
    if command -v "$cmd" &>/dev/null; then
        VERSION=$("$cmd" --version 2>&1 | cut -d' ' -f2)
        MAJOR=$(echo "$VERSION" | cut -d'.' -f1)
        MINOR=$(echo "$VERSION" | cut -d'.' -f2)
        if [[ "$MAJOR" -ge 3 && "$MINOR" -ge 8 ]]; then
            PYTHON_CMD="$cmd"
            echo "Using Python: $cmd ($VERSION)"
            break
        fi
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    echo "Error: Python 3.8+ not found"
    exit 1
fi

# Check if vault exists
if [[ ! -d "$VAULT_PATH" ]]; then
    echo "Error: Vault not found at $VAULT_PATH"
    echo "Usage: $0 [vault_path]"
    exit 1
fi
echo "Vault path: $VAULT_PATH"
echo ""

# Create virtual environment
echo "Creating virtual environment at $VENV_DIR..."
mkdir -p "$(dirname "$VENV_DIR")"
"$PYTHON_CMD" -m venv "$VENV_DIR"

# Install dependencies
echo "Installing Python dependencies..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet sentence-transformers numpy

# Verify installation
echo "Verifying installation..."
"$VENV_DIR/bin/python" -c "from sentence_transformers import SentenceTransformer; print('  sentence-transformers: OK')"
"$VENV_DIR/bin/python" -c "import numpy; print('  numpy: OK')"

echo ""

# Make scripts executable
chmod +x "$SCRIPT_DIR/vault-index.py"
chmod +x "$SCRIPT_DIR/vault-search.py"

# Build initial index
echo "Building initial index (this may take a minute)..."
echo ""
"$SCRIPT_DIR/vault-index.py" "$VAULT_PATH" --force

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Commands available:"
echo "  Index vault:    $SCRIPT_DIR/vault-index.py $VAULT_PATH"
echo "  Search:         $SCRIPT_DIR/vault-search.py \"note.md\""
echo "  Text query:     $SCRIPT_DIR/vault-search.py --query \"your search\""
echo ""
echo "Neovim keybindings:"
echo "  <leader>or    Related notes (semantic)"
echo "  <leader>oR    Semantic search (text query)"
echo ""
