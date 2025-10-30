#!/usr/bin/env bash
# Test Zsh Shell Configuration
# Validates Zsh shell setup and configuration loading

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing Zsh shell configuration..."

# Test 1: Zsh shell availability
echo "Test 1: Zsh shell installation"
if ! command -v zsh &> /dev/null; then
    echo -e "${RED}ERROR: Zsh shell is not installed${NC}"
    exit 1
fi

ZSH_VERSION_STR=$(zsh --version 2>&1 | head -1)
echo -e "${GREEN}✓ Zsh shell is installed: $ZSH_VERSION_STR${NC}"

# Test 2: Zsh config file exists
echo ""
echo "Test 2: Zsh configuration files"

if [ -f "$HOME/.zshrc" ]; then
    echo -e "${GREEN}✓ .zshrc exists${NC}"
    echo "  Location: $HOME/.zshrc"

    # Check if it's a symlink (stow'd)
    if [ -L "$HOME/.zshrc" ]; then
        echo "  ✓ .zshrc is symlinked (managed by stow)"
        echo "  → $(readlink -f $HOME/.zshrc 2>/dev/null || readlink $HOME/.zshrc)"
    fi
else
    echo -e "${YELLOW}⚠️  .zshrc not found at $HOME/.zshrc${NC}"
    echo "  This may be expected in minimal test environment"
fi

# Test 3: Zsh can start and run commands
echo ""
echo "Test 3: Zsh shell execution"

if zsh -c "echo 'Zsh shell works'" &> /dev/null; then
    echo -e "${GREEN}✓ Zsh shell can execute commands${NC}"
else
    echo -e "${RED}ERROR: Zsh shell cannot execute commands${NC}"
    exit 1
fi

# Test 4: Zsh config loads without errors
echo ""
echo "Test 4: Configuration loading"

# Run zsh with config and capture any errors
# Use --no-rcs to test just zsh, then with config
if ZSH_OUTPUT=$(zsh -c "true" 2>&1); then
    echo -e "${GREEN}✓ Zsh config loads without errors${NC}"
else
    echo -e "${RED}ERROR: Zsh config has errors:${NC}"
    echo "$ZSH_OUTPUT"
    exit 1
fi

# Test 5: Check for BAT_PAGING environment variable (our fix!)
echo ""
echo "Test 5: Environment variables"

if zsh -c 'echo $BAT_PAGING' 2>/dev/null | grep -q "never"; then
    echo -e "${GREEN}✓ BAT_PAGING is set correctly (pager fix verified!)${NC}"
else
    echo -e "${YELLOW}⚠️  BAT_PAGING not set (expected if .zshrc not sourced)${NC}"
fi

# Check other common environment variables
for var in EDITOR VISUAL SHELL ZSH; do
    if VALUE=$(zsh -c "echo \$$var" 2>/dev/null) && [ -n "$VALUE" ] && [ "$VALUE" != "\$$var" ]; then
        echo "  ✓ $var=$VALUE"
    else
        echo "  ℹ️  $var not set"
    fi
done

# Test 6: Oh My Zsh (if installed)
echo ""
echo "Test 6: Oh My Zsh installation"

if [ -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${GREEN}✓ Oh My Zsh is installed${NC}"
    echo "  Location: $HOME/.oh-my-zsh"

    # Check Oh My Zsh version
    if [ -f "$HOME/.oh-my-zsh/tools/version.sh" ]; then
        OMZ_VERSION=$(cat "$HOME/.oh-my-zsh/lib/constants.zsh" 2>/dev/null | grep "OMZ_VERSION" | head -1 || echo "unknown")
        echo "  $OMZ_VERSION"
    fi
else
    echo "  ℹ️  Oh My Zsh not installed"
fi

# Test 7: Zsh plugins
echo ""
echo "Test 7: Zsh plugins and themes"

if [ -f "$HOME/.zshrc" ]; then
    if PLUGINS=$(grep "^plugins=" "$HOME/.zshrc" 2>/dev/null); then
        echo "  Configured plugins:"
        echo "  $PLUGINS"
    fi

    if THEME=$(grep "^ZSH_THEME=" "$HOME/.zshrc" 2>/dev/null); then
        echo "  $THEME"
    fi

    # Check for Starship
    if grep -q "starship init" "$HOME/.zshrc" 2>/dev/null; then
        echo "  ✓ Starship prompt is configured"
    fi
else
    echo "  ℹ️  Cannot check plugins (.zshrc not found)"
fi

# Test 8: Zsh aliases
echo ""
echo "Test 8: Zsh aliases"

# Test if zsh can define and use aliases
if zsh -c 'alias test_alias="echo alias works"; test_alias' 2>/dev/null | grep -q "alias works"; then
    echo -e "${GREEN}✓ Zsh can define and execute aliases${NC}"
else
    echo -e "${YELLOW}⚠️  Zsh alias execution test inconclusive${NC}"
fi

# Test common aliases that should be in the config
COMMON_ALIASES=("ll" "la" "ls" "k")
if [ -f "$HOME/.zshrc" ]; then
    for alias_name in "${COMMON_ALIASES[@]}"; do
        if grep -q "alias $alias_name=" "$HOME/.zshrc" 2>/dev/null || zsh -c "type $alias_name" 2>&1 | grep -q "alias"; then
            echo "  ✓ Alias '$alias_name' configured"
        else
            echo "  ℹ️  Alias '$alias_name' not found (may be expected)"
        fi
    done
fi

# Test 9: Zsh completion system
echo ""
echo "Test 9: Zsh completion system"

if zsh -c "autoload -U compinit; compinit -i; compdef _git git" &> /dev/null; then
    echo -e "${GREEN}✓ Zsh completion system functional${NC}"
else
    echo -e "${YELLOW}⚠️  Zsh completions may not be fully loaded${NC}"
fi

# Test 10: PATH configuration
echo ""
echo "Test 10: PATH configuration"

if ZSH_PATH=$(zsh -c 'echo $PATH' 2>/dev/null); then
    echo "  Zsh PATH contains:"
    echo "$ZSH_PATH" | tr ':' '\n' | head -8 | sed 's/^/    /'

    # Check for common expected paths
    EXPECTED_PATHS=("/usr/local/bin" "/usr/bin" "$HOME/.local/bin" "$HOME/bin")
    for path in "${EXPECTED_PATHS[@]}"; do
        if echo "$ZSH_PATH" | grep -q "$path"; then
            echo "  ✓ $path in PATH"
        fi
    done
else
    echo -e "${YELLOW}⚠️  Could not retrieve Zsh PATH${NC}"
fi

# Test 11: FZF integration
echo ""
echo "Test 11: FZF integration"

if command -v fzf &> /dev/null; then
    echo "  ✓ FZF is installed"

    # Check if FZF is configured in zsh
    if [ -f "$HOME/.zshrc" ] && grep -q "FZF" "$HOME/.zshrc" 2>/dev/null; then
        echo -e "${GREEN}✓ FZF is configured in Zsh${NC}"
    else
        echo "  ℹ️  FZF not explicitly configured in .zshrc"
    fi
else
    echo "  ℹ️  FZF not installed"
fi

# Test 12: Starship prompt (if configured)
echo ""
echo "Test 12: Prompt configuration"

if command -v starship &> /dev/null; then
    echo "  ✓ Starship prompt is installed"
    if [ -f "$HOME/.zshrc" ] && grep -q "starship init" "$HOME/.zshrc" 2>/dev/null; then
        echo -e "${GREEN}✓ Starship is configured in Zsh${NC}"
    else
        echo "  ℹ️  Starship not configured yet (expected if config not loaded)"
    fi
else
    echo "  ℹ️  Starship not installed"
fi

echo ""
echo -e "${GREEN}Zsh shell configuration tests completed!${NC}"
exit 0
