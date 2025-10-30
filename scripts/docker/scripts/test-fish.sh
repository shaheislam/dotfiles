#!/usr/bin/env bash
# Test Fish Shell Configuration
# Validates Fish shell setup and configuration loading

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing Fish shell configuration..."

# Test 1: Fish shell availability
echo "Test 1: Fish shell installation"
if ! command -v fish &> /dev/null; then
    echo -e "${RED}ERROR: Fish shell is not installed${NC}"
    exit 1
fi

FISH_VERSION=$(fish --version 2>&1 | head -1)
echo -e "${GREEN}✓ Fish shell is installed: $FISH_VERSION${NC}"

# Test 2: Fish config file exists
echo ""
echo "Test 2: Fish configuration files"

if [ -f "$HOME/.config/fish/config.fish" ]; then
    echo -e "${GREEN}✓ Fish config.fish exists${NC}"
    echo "  Location: $HOME/.config/fish/config.fish"

    # Check if it's a symlink (stow'd)
    if [ -L "$HOME/.config/fish/config.fish" ]; then
        echo "  ✓ Config is symlinked (managed by stow)"
        echo "  → $(readlink -f $HOME/.config/fish/config.fish 2>/dev/null || readlink $HOME/.config/fish/config.fish)"
    fi
else
    echo -e "${YELLOW}⚠️  Fish config.fish not found at $HOME/.config/fish/config.fish${NC}"
    echo "  This may be expected in minimal test environment"
fi

# Test 3: Fish can start and run commands
echo ""
echo "Test 3: Fish shell execution"

if fish -c "echo 'Fish shell works'" &> /dev/null; then
    echo -e "${GREEN}✓ Fish shell can execute commands${NC}"
else
    echo -e "${RED}ERROR: Fish shell cannot execute commands${NC}"
    exit 1
fi

# Test 4: Fish config loads without errors
echo ""
echo "Test 4: Configuration loading"

# Run fish with config and capture any errors
if FISH_OUTPUT=$(fish -c "true" 2>&1); then
    echo -e "${GREEN}✓ Fish config loads without errors${NC}"
else
    echo -e "${RED}ERROR: Fish config has errors:${NC}"
    echo "$FISH_OUTPUT"
    exit 1
fi

# Test 5: Check for BAT_PAGING environment variable (our fix!)
echo ""
echo "Test 5: Environment variables"

if fish -c 'echo $BAT_PAGING' 2>/dev/null | grep -q "never"; then
    echo -e "${GREEN}✓ BAT_PAGING is set correctly (pager fix verified!)${NC}"
else
    echo -e "${YELLOW}⚠️  BAT_PAGING not set (expected if config not stow'd yet)${NC}"
fi

# Check other common environment variables
for var in EDITOR VISUAL SHELL; do
    if VALUE=$(fish -c "echo \$$var" 2>/dev/null) && [ -n "$VALUE" ] && [ "$VALUE" != "\$$var" ]; then
        echo "  ✓ $var=$VALUE"
    else
        echo "  ℹ️  $var not set"
    fi
done

# Test 6: Fish functions (if config is loaded)
echo ""
echo "Test 6: Fish functions and aliases"

# Test if fish can define and execute functions
if fish -c 'function test_func; echo "function works"; end; test_func' 2>/dev/null | grep -q "function works"; then
    echo -e "${GREEN}✓ Fish can define and execute functions${NC}"
else
    echo -e "${YELLOW}⚠️  Fish function execution test inconclusive${NC}"
fi

# Test common aliases that should be in the config
COMMON_ALIASES=("ll" "la" "ls")
for alias_name in "${COMMON_ALIASES[@]}"; do
    if fish -c "type -q $alias_name" 2>/dev/null; then
        echo "  ✓ Alias/function '$alias_name' available"
    else
        echo "  ℹ️  Alias/function '$alias_name' not found (may be expected)"
    fi
done

# Test 7: Fish completion system
echo ""
echo "Test 7: Fish completion system"

if fish -c "complete -C 'git '" &> /dev/null; then
    echo -e "${GREEN}✓ Fish completion system functional${NC}"
else
    echo -e "${YELLOW}⚠️  Fish completions may not be fully loaded${NC}"
fi

# Test 8: Fish plugin manager (Fisher) if present
echo ""
echo "Test 8: Fish plugin system"

if fish -c "type -q fisher" 2>/dev/null; then
    echo -e "${GREEN}✓ Fisher plugin manager is installed${NC}"
    if PLUGINS=$(fish -c "fisher list" 2>/dev/null); then
        echo "  Installed plugins:"
        echo "$PLUGINS" | head -5 | sed 's/^/    /'
    fi
elif [ -f "$HOME/.config/fish/functions/fisher.fish" ]; then
    echo "  ✓ Fisher function file exists"
else
    echo "  ℹ️  Fisher not detected (may not be installed yet)"
fi

# Test 9: PATH configuration
echo ""
echo "Test 9: PATH configuration"

if FISH_PATH=$(fish -c 'echo $PATH' 2>/dev/null); then
    echo "  Fish PATH contains:"
    echo "$FISH_PATH" | tr ' ' '\n' | head -8 | sed 's/^/    /'

    # Check for common expected paths
    EXPECTED_PATHS=("/usr/local/bin" "/usr/bin" "$HOME/.local/bin")
    for path in "${EXPECTED_PATHS[@]}"; do
        if echo "$FISH_PATH" | grep -q "$path"; then
            echo "  ✓ $path in PATH"
        fi
    done
else
    echo -e "${YELLOW}⚠️  Could not retrieve Fish PATH${NC}"
fi

# Test 10: Starship prompt (if configured)
echo ""
echo "Test 10: Prompt configuration"

if command -v starship &> /dev/null; then
    echo "  ✓ Starship prompt is installed"
    if fish -c "type -q starship_transient_prompt_func" 2>/dev/null; then
        echo -e "${GREEN}✓ Starship is configured in Fish${NC}"
    else
        echo "  ℹ️  Starship not configured yet (expected if config not loaded)"
    fi
else
    echo "  ℹ️  Starship not installed"
fi

echo ""
echo -e "${GREEN}Fish shell configuration tests completed!${NC}"
exit 0
