#!/usr/bin/env bash
# Test Setup Script Validation
# Validates that setup.sh correctly installs packages and tools

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing setup.sh script validation..."

# Test 1: Setup script exists and is executable
echo ""
echo "Test 1: Setup script availability"

if [ -f "$HOME/dotfiles/scripts/setup.sh" ]; then
    echo -e "${GREEN}✓ setup.sh exists${NC}"

    if [ -x "$HOME/dotfiles/scripts/setup.sh" ]; then
        echo -e "${GREEN}✓ setup.sh is executable${NC}"
    else
        echo -e "${RED}ERROR: setup.sh is not executable${NC}"
        exit 1
    fi
else
    echo -e "${RED}ERROR: setup.sh not found${NC}"
    exit 1
fi

# Test 2: Package manager detection
echo ""
echo "Test 2: Package manager detection"

cd "$HOME/dotfiles"

# Source common libraries
if [ -f "scripts/lib/common.sh" ]; then
    source "scripts/lib/common.sh"
    echo -e "${GREEN}✓ common.sh loaded${NC}"
else
    echo -e "${RED}ERROR: common.sh not found${NC}"
    exit 1
fi

# Detect OS and package manager
DETECTED_OS=$(detect_os)
echo "  Detected OS: $DETECTED_OS"

if [ "$DETECTED_OS" = "linux" ]; then
    # Source Linux package manager
    if [ -f "scripts/os/linux/package-manager.sh" ]; then
        source "scripts/os/linux/package-manager.sh"
        echo -e "${GREEN}✓ Linux package manager loaded${NC}"

        # Initialize package manager
        if pm_init; then
            echo -e "${GREEN}✓ Package manager initialized: $LINUX_PM${NC}"
        else
            echo -e "${RED}ERROR: Package manager initialization failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}ERROR: Linux package manager script not found${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Not on Linux, skipping package manager tests${NC}"
    exit 0
fi

# Test 3: Package name mapping
echo ""
echo "Test 3: Package name mapping"

CORE_TOOLS=("git" "curl" "wget" "stow" "tmux" "neovim" "bat" "ripgrep" "fd" "fzf")
MAPPED_COUNT=0
BINARY_COUNT=0

for tool in "${CORE_TOOLS[@]}"; do
    mapped=$(pm_map_package_name "$tool")

    if [ -n "$mapped" ]; then
        ((MAPPED_COUNT++)) || true
        if [[ "$mapped" == BINARY_INSTALL:* ]]; then
            ((BINARY_COUNT++)) || true
            echo "  ✓ $tool → $mapped (binary install)"
        else
            echo "  ✓ $tool → $mapped"
        fi
    else
        echo "  ℹ️  $tool → (skipped - macOS only)"
    fi
done

echo -e "${GREEN}✓ Mapped ${MAPPED_COUNT}/${#CORE_TOOLS[@]} core tools${NC}"
echo "  Binary installations required: $BINARY_COUNT"

# Test 4: Binary installer availability
echo ""
echo "Test 4: Binary installer"

if [ -f "scripts/lib/binary-installer.sh" ]; then
    source "scripts/lib/binary-installer.sh"
    echo -e "${GREEN}✓ binary-installer.sh loaded${NC}"

    # Test binary URL generation for key tools
    TEST_BINARIES=("starship" "eza" "kubectl" "helm" "granted")
    URL_COUNT=0

    for binary in "${TEST_BINARIES[@]}"; do
        url=$(get_binary_download_url "$binary")
        if [ -n "$url" ]; then
            ((URL_COUNT++)) || true
            echo "  ✓ $binary: URL generated"
        else
            echo "  ✗ $binary: No URL"
        fi
    done

    echo -e "${GREEN}✓ Generated URLs for ${URL_COUNT}/${#TEST_BINARIES[@]} test binaries${NC}"
else
    echo -e "${RED}ERROR: binary-installer.sh not found${NC}"
    exit 1
fi

# Test 5: Profile system
echo ""
echo "Test 5: Profile system"

PROFILES=("minimal" "standard" "comprehensive" "dev" "ops")
PROFILE_COUNT=0

for profile in "${PROFILES[@]}"; do
    if [ -f "scripts/profiles/${profile}.sh" ]; then
        ((PROFILE_COUNT++)) || true
        echo "  ✓ Profile exists: $profile"
    else
        echo "  ✗ Profile missing: $profile"
    fi
done

if [ $PROFILE_COUNT -eq ${#PROFILES[@]} ]; then
    echo -e "${GREEN}✓ All ${#PROFILES[@]} profiles available${NC}"
else
    echo -e "${YELLOW}⚠️  Only ${PROFILE_COUNT}/${#PROFILES[@]} profiles found${NC}"
fi

# Test 6: Stow availability
echo ""
echo "Test 6: GNU Stow"

if command -v stow &> /dev/null; then
    STOW_VERSION=$(stow --version 2>&1 | head -1)
    echo -e "${GREEN}✓ GNU Stow is installed: $STOW_VERSION${NC}"
else
    echo -e "${RED}ERROR: GNU Stow not installed${NC}"
    exit 1
fi

# Test 7: Shell availability
echo ""
echo "Test 7: Shell availability"

SHELLS_FOUND=0

if command -v fish &> /dev/null; then
    FISH_VERSION=$(fish --version 2>&1)
    echo "  ✓ Fish: $FISH_VERSION"
    ((SHELLS_FOUND++)) || true
else
    echo "  ✗ Fish not installed"
fi

if command -v zsh &> /dev/null; then
    ZSH_VERSION=$(zsh --version 2>&1 | head -1)
    echo "  ✓ Zsh: $ZSH_VERSION"
    ((SHELLS_FOUND++)) || true
else
    echo "  ✗ Zsh not installed"
fi

if [ $SHELLS_FOUND -gt 0 ]; then
    echo -e "${GREEN}✓ Found ${SHELLS_FOUND} alternative shells${NC}"
else
    echo -e "${YELLOW}⚠️  No alternative shells installed${NC}"
fi

# Test 8: Modern CLI tools
echo ""
echo "Test 8: Modern CLI tools"

MODERN_TOOLS=("bat" "ripgrep" "fd" "fzf" "eza" "zoxide" "starship")
TOOLS_FOUND=0

for tool in "${MODERN_TOOLS[@]}"; do
    # Handle aliases (bat → batcat, fd → fdfind)
    actual_cmd="$tool"
    case "$tool" in
        bat)
            if command -v batcat &> /dev/null; then
                actual_cmd="batcat"
            fi
            ;;
        fd)
            if command -v fdfind &> /dev/null; then
                actual_cmd="fdfind"
            fi
            ;;
    esac

    if command -v "$actual_cmd" &> /dev/null; then
        echo "  ✓ $tool (as $actual_cmd)"
        ((TOOLS_FOUND++)) || true
    else
        echo "  ✗ $tool not found"
    fi
done

echo "  Found ${TOOLS_FOUND}/${#MODERN_TOOLS[@]} modern tools"

# Test 9: Kubernetes tools (if comprehensive/ops profile)
echo ""
echo "Test 9: Kubernetes/DevOps tools"

DEVOPS_TOOLS=("kubectl" "helm" "k9s")
DEVOPS_FOUND=0

for tool in "${DEVOPS_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "  ✓ $tool"
        ((DEVOPS_FOUND++)) || true
    else
        echo "  ℹ️  $tool not found (optional)"
    fi
done

if [ $DEVOPS_FOUND -gt 0 ]; then
    echo -e "${GREEN}✓ Found ${DEVOPS_FOUND}/${#DEVOPS_TOOLS[@]} DevOps tools${NC}"
else
    echo "  ℹ️  No DevOps tools installed (expected for minimal profiles)"
fi

# Test 10: Git configuration
echo ""
echo "Test 10: Git configuration"

if [ -f "$HOME/.gitconfig" ]; then
    echo -e "${GREEN}✓ .gitconfig exists${NC}"

    if [ -L "$HOME/.gitconfig" ]; then
        TARGET=$(readlink -f "$HOME/.gitconfig" 2>/dev/null || readlink "$HOME/.gitconfig")
        echo "  ✓ .gitconfig is symlinked"
        echo "  → $TARGET"
    fi
else
    echo "  ℹ️  .gitconfig not found (not yet stowed)"
fi

# Summary
echo ""
echo -e "${GREEN}Setup script validation tests completed!${NC}"
echo ""
echo "Summary:"
echo "  ✓ setup.sh: Available and executable"
echo "  ✓ Package manager: $LINUX_PM detected and initialized"
echo "  ✓ Package mappings: ${MAPPED_COUNT} core tools mapped"
echo "  ✓ Binary installer: Available with URL generation"
echo "  ✓ Profiles: ${PROFILE_COUNT}/${#PROFILES[@]} available"
echo "  ✓ Shells: ${SHELLS_FOUND} alternative shells"
echo "  ✓ Modern tools: ${TOOLS_FOUND}/${#MODERN_TOOLS[@]} installed"
echo "  ℹ️  DevOps tools: ${DEVOPS_FOUND} installed (profile-dependent)"

exit 0
