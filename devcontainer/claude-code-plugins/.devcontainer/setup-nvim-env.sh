#!/bin/bash
# setup-nvim-env.sh - Setup XDG symlinks to persistent env directory
# This script links XDG directories to a mounted volume for Neovim config persistence

set -e

HOME_DIR="/home/node"
ENV_DIR="/devcontainer/env"

echo "Setting up Neovim environment..."

# Check if env directory is mounted
if [[ ! -d "$ENV_DIR" ]]; then
    echo "Warning: $ENV_DIR not mounted. Skipping XDG symlink setup."
    echo "To enable Neovim config persistence, mount ~/.devcontainer/env to /devcontainer/env"
    exit 0
fi

# Create env subdirectories if they don't exist
mkdir -p "$ENV_DIR/.config" "$ENV_DIR/.cache" "$ENV_DIR/.local"

# Function to setup symlink
setup_symlink() {
    local target="$1"
    local link="$2"

    # Remove existing directory/file if it exists (but not if it's already the correct symlink)
    if [[ -L "$link" ]]; then
        local current_target
        current_target=$(readlink "$link")
        if [[ "$current_target" == "$target" ]]; then
            echo "  $link already linked correctly"
            return
        fi
        rm "$link"
    elif [[ -e "$link" ]]; then
        # Backup existing content if it's a real directory with content
        if [[ -d "$link" ]] && [[ "$(ls -A "$link" 2>/dev/null)" ]]; then
            echo "  Backing up existing $link to ${link}.bak"
            mv "$link" "${link}.bak"
        else
            rm -rf "$link"
        fi
    fi

    # Create symlink
    ln -s "$target" "$link"
    echo "  Linked: $link -> $target"
}

# Setup XDG directory symlinks
echo "Creating XDG directory symlinks..."
setup_symlink "$ENV_DIR/.config" "$HOME_DIR/.config"
setup_symlink "$ENV_DIR/.cache" "$HOME_DIR/.cache"
setup_symlink "$ENV_DIR/.local" "$HOME_DIR/.local"

# Setup Neovim config symlink
NVIM_MOUNT="/devcontainer/neovim"
NVIM_CONFIG="$ENV_DIR/.config/nvim"

if [[ -d "$NVIM_MOUNT" ]]; then
    echo "Neovim config mount found at $NVIM_MOUNT"

    # Remove any existing nvim config (symlink or directory)
    if [[ -L "$NVIM_CONFIG" ]] || [[ -e "$NVIM_CONFIG" ]]; then
        rm -rf "$NVIM_CONFIG"
    fi

    # Create symlink to mounted neovim config
    ln -s "$NVIM_MOUNT" "$NVIM_CONFIG"
    echo "  Linked: $NVIM_CONFIG -> $NVIM_MOUNT"

    # Count plugins if lazy-lock.json exists
    if [[ -f "$NVIM_CONFIG/lazy-lock.json" ]]; then
        plugin_count=$(grep -c '"' "$NVIM_CONFIG/lazy-lock.json" 2>/dev/null | head -1 || echo "0")
        echo "  Detected $((plugin_count / 2)) plugins in lazy-lock.json"
    fi
elif [[ -d "$NVIM_CONFIG" ]]; then
    echo "Neovim configuration found at $NVIM_CONFIG"
else
    echo "Note: No Neovim config found. To use your config:"
    echo "  1. Ensure ~/neovim exists on host"
    echo "  2. Rebuild the container"
fi

# Configure git safe.directory for lazy plugins (fixes ownership mismatch between host/container)
LAZY_DIR="$ENV_DIR/.local/share/nvim/lazy"
if [[ -d "$LAZY_DIR" ]]; then
    echo "Configuring git safe.directory for lazy plugins..."
    git config --global --add safe.directory '*'
    echo "  Added wildcard safe.directory (allows all directories)"
fi

# Compile treesitter parsers from cached sources
# Parsers are stored in /tmp (ephemeral) but sources are cached in the mounted volume
# This compiles them on each container start for instant syntax highlighting
CACHE_DIR="$ENV_DIR/.cache/nvim"
PARSER_DIR="/tmp/nvim-treesitter-parsers/parser"

if [[ -d "$CACHE_DIR" ]]; then
    echo "Compiling treesitter parsers from cache..."
    mkdir -p "$PARSER_DIR"

    compile_parser() {
        local lang=$1
        local src_dir=$2

        if [[ -f "$src_dir/parser.c" ]]; then
            local scanner=""
            [[ -f "$src_dir/scanner.c" ]] && scanner="scanner.c"
            [[ -f "$src_dir/scanner.cc" ]] && scanner="scanner.cc"

            if [[ -n "$scanner" ]]; then
                (cd "$src_dir" && cc -shared -fPIC -o "$PARSER_DIR/$lang.so" parser.c "$scanner" -I. 2>/dev/null) && echo "  ✓ $lang"
            else
                (cd "$src_dir" && cc -shared -fPIC -o "$PARSER_DIR/$lang.so" parser.c -I. 2>/dev/null) && echo "  ✓ $lang"
            fi
        fi
    }

    # Standard parsers (source in src/ subdirectory)
    for lang in lua vim bash json query fish python javascript yaml toml vimdoc; do
        compile_parser "$lang" "$CACHE_DIR/tree-sitter-$lang/src"
    done

    # Markdown has nested structure
    compile_parser "markdown" "$CACHE_DIR/tree-sitter-markdown/tree-sitter-markdown/src"
    compile_parser "markdown_inline" "$CACHE_DIR/tree-sitter-markdown_inline/tree-sitter-markdown-inline/src"

    # Typescript has tmp directory with versioned subdirectory
    ts_dir=$(find "$CACHE_DIR" -maxdepth 2 -type d -name "tree-sitter-typescript-*" 2>/dev/null | head -1)
    if [[ -n "$ts_dir" ]]; then
        compile_parser "typescript" "$ts_dir/typescript/src"
        compile_parser "tsx" "$ts_dir/tsx/src"
    fi

    parser_count=$(ls "$PARSER_DIR"/*.so 2>/dev/null | wc -l)
    echo "  Compiled $parser_count treesitter parsers"
fi

echo "XDG directories linked to persistent storage"
echo "Neovim environment setup complete!"
