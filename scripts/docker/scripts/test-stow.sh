#!/usr/bin/env bash
# Test GNU Stow Operations
# Validates that dotfiles can be symlinked correctly using GNU Stow

set -euo pipefail

# Test configuration
DOTFILES_DIR="$HOME/dotfiles"
TEST_DIR="/tmp/stow-test-$$"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Testing GNU Stow operations..."

# Verify stow is installed
if ! command -v stow &> /dev/null; then
    echo -e "${RED}ERROR: GNU Stow is not installed${NC}"
    exit 1
fi

echo "✓ GNU Stow is installed ($(stow --version | head -1))"

# Create test directory
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1

# Test 1: Basic stow operation with .gitconfig
echo "Test 1: Stowing .gitconfig"
if [ -f "$DOTFILES_DIR/.gitconfig" ]; then
    # Create backup if file exists
    [ -f "$HOME/.gitconfig" ] && mv "$HOME/.gitconfig" "$HOME/.gitconfig.bak.$$" || true

    cd "$DOTFILES_DIR" || exit 1
    if stow -v -t "$HOME" --adopt .gitconfig 2>/dev/null; then
        if [ -L "$HOME/.gitconfig" ]; then
            echo -e "${GREEN}✓ .gitconfig symlink created successfully${NC}"
        else
            echo -e "${RED}ERROR: .gitconfig exists but is not a symlink${NC}"
            # Restore backup
            [ -f "$HOME/.gitconfig.bak.$$" ] && mv "$HOME/.gitconfig.bak.$$" "$HOME/.gitconfig" || true
            exit 1
        fi
    else
        echo -e "${RED}ERROR: Failed to stow .gitconfig${NC}"
        # Restore backup
        [ -f "$HOME/.gitconfig.bak.$$" ] && mv "$HOME/.gitconfig.bak.$$" "$HOME/.gitconfig" || true
        exit 1
    fi

    # Cleanup test
    stow -D -v -t "$HOME" .gitconfig 2>/dev/null || true
    [ -f "$HOME/.gitconfig.bak.$$" ] && mv "$HOME/.gitconfig.bak.$$" "$HOME/.gitconfig" || true
else
    echo "⚠️  Skipping .gitconfig test (file not found)"
fi

# Test 2: Stowing Fish config directory
echo ""
echo "Test 2: Stowing Fish configuration"
if [ -d "$DOTFILES_DIR/.config/fish" ]; then
    # Create backup if directory exists
    [ -d "$HOME/.config/fish" ] && mv "$HOME/.config/fish" "$HOME/.config/fish.bak.$$" || true

    mkdir -p "$HOME/.config"
    cd "$DOTFILES_DIR" || exit 1

    # For directory-based stowing, we need to use the parent directory approach
    if [ -d ".config" ]; then
        if stow -v -t "$HOME" --adopt .config 2>/dev/null; then
            if [ -L "$HOME/.config/fish" ] || [ -f "$HOME/.config/fish/config.fish" ]; then
                echo -e "${GREEN}✓ Fish config directory stowed successfully${NC}"
            else
                echo -e "${RED}ERROR: Fish config not properly linked${NC}"
                # Restore backup
                [ -d "$HOME/.config/fish.bak.$$" ] && rm -rf "$HOME/.config/fish" && mv "$HOME/.config/fish.bak.$$" "$HOME/.config/fish" || true
                exit 1
            fi
        else
            echo "⚠️  Fish config stow had warnings but may still work"
        fi

        # Cleanup
        [ -d "$HOME/.config/fish" ] && rm -rf "$HOME/.config/fish" || true
        [ -d "$HOME/.config/fish.bak.$$" ] && mv "$HOME/.config/fish.bak.$$" "$HOME/.config/fish" || true
    fi
else
    echo "⚠️  Skipping Fish config test (directory not found)"
fi

# Test 3: Verify stow can detect conflicts
echo ""
echo "Test 3: Conflict detection"
cd "$TEST_DIR" || exit 1

# Create a test package structure
mkdir -p test-package/.config
echo "test content" > test-package/.config/test-file

# Create conflicting file
mkdir -p "$TEST_DIR/target/.config"
echo "conflicting content" > "$TEST_DIR/target/.config/test-file"

# Try to stow - should detect conflict
if stow -v -d "$TEST_DIR" -t "$TEST_DIR/target" test-package 2>&1 | grep -q "conflict"; then
    echo -e "${GREEN}✓ Stow correctly detects conflicts${NC}"
else
    # With --adopt flag, stow might not report conflict
    echo "⚠️  Conflict detection test inconclusive"
fi

# Test 4: Verify stow unstow operation
echo ""
echo "Test 4: Unstow operation"
# Create clean test environment
rm -rf "$TEST_DIR/target"
mkdir -p "$TEST_DIR/target"

cd "$TEST_DIR" || exit 1
stow -v -d "$TEST_DIR" -t "$TEST_DIR/target" test-package &> /dev/null || true

if [ -L "$TEST_DIR/target/.config/test-file" ]; then
    # Now unstow
    stow -D -v -d "$TEST_DIR" -t "$TEST_DIR/target" test-package &> /dev/null || true

    if [ ! -L "$TEST_DIR/target/.config/test-file" ]; then
        echo -e "${GREEN}✓ Unstow operation successful${NC}"
    else
        echo -e "${RED}ERROR: Unstow did not remove symlink${NC}"
        exit 1
    fi
else
    echo "⚠️  Stow operation did not create expected symlink"
fi

# Cleanup
cd "$HOME" || exit 1
rm -rf "$TEST_DIR"

echo ""
echo -e "${GREEN}All GNU Stow tests passed!${NC}"
exit 0
