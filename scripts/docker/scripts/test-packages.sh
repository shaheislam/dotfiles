#!/usr/bin/env bash
# Test Package Manager Detection and Operations
# Validates package manager detection across different distributions

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing package manager detection and operations..."

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$ID"
    echo "✓ Detected distribution: $NAME ($DISTRO)"
else
    echo -e "${RED}ERROR: Cannot detect distribution${NC}"
    exit 1
fi

# Test 1: Package manager availability
echo ""
echo "Test 1: Package manager detection"

case "$DISTRO" in
    ubuntu|debian)
        if command -v apt-get &> /dev/null; then
            echo -e "${GREEN}✓ apt-get is available${NC}"
            echo "  Version: $(apt-get --version | head -1)"
        else
            echo -e "${RED}ERROR: apt-get not found on Debian-based system${NC}"
            exit 1
        fi
        PM="apt-get"
        ;;

    fedora|rhel|centos)
        if command -v dnf &> /dev/null; then
            echo -e "${GREEN}✓ dnf is available${NC}"
            echo "  Version: $(dnf --version | head -1)"
            PM="dnf"
        elif command -v yum &> /dev/null; then
            echo -e "${GREEN}✓ yum is available${NC}"
            echo "  Version: $(yum --version | head -1)"
            PM="yum"
        else
            echo -e "${RED}ERROR: Neither dnf nor yum found on RHEL-based system${NC}"
            exit 1
        fi
        ;;

    arch|manjaro)
        if command -v pacman &> /dev/null; then
            echo -e "${GREEN}✓ pacman is available${NC}"
            echo "  Version: $(pacman --version | head -1)"
            PM="pacman"
        else
            echo -e "${RED}ERROR: pacman not found on Arch-based system${NC}"
            exit 1
        fi
        ;;

    alpine)
        if command -v apk &> /dev/null; then
            echo -e "${GREEN}✓ apk is available${NC}"
            echo "  Version: $(apk --version | head -1)"
            PM="apk"
        else
            echo -e "${RED}ERROR: apk not found on Alpine${NC}"
            exit 1
        fi
        ;;

    *)
        echo -e "${YELLOW}⚠️  Unknown distribution: $DISTRO${NC}"
        echo "  Will attempt generic detection"
        if command -v apt-get &> /dev/null; then
            PM="apt-get"
        elif command -v dnf &> /dev/null; then
            PM="dnf"
        elif command -v yum &> /dev/null; then
            PM="yum"
        elif command -v pacman &> /dev/null; then
            PM="pacman"
        elif command -v apk &> /dev/null; then
            PM="apk"
        else
            echo -e "${RED}ERROR: No supported package manager found${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Found package manager: $PM${NC}"
        ;;
esac

# Test 2: Package manager can query packages
echo ""
echo "Test 2: Package query operations"

case "$PM" in
    apt-get)
        if dpkg -l git &> /dev/null; then
            echo -e "${GREEN}✓ Can query installed packages (git)${NC}"
        else
            echo -e "${RED}ERROR: Cannot query packages with dpkg${NC}"
            exit 1
        fi
        ;;

    dnf|yum)
        if rpm -q git &> /dev/null; then
            echo -e "${GREEN}✓ Can query installed packages (git)${NC}"
        else
            echo -e "${RED}ERROR: Cannot query packages with rpm${NC}"
            exit 1
        fi
        ;;

    pacman)
        if pacman -Q git &> /dev/null; then
            echo -e "${GREEN}✓ Can query installed packages (git)${NC}"
        else
            echo -e "${RED}ERROR: Cannot query packages with pacman${NC}"
            exit 1
        fi
        ;;

    apk)
        if apk info git &> /dev/null; then
            echo -e "${GREEN}✓ Can query installed packages (git)${NC}"
        else
            echo -e "${RED}ERROR: Cannot query packages with apk${NC}"
            exit 1
        fi
        ;;
esac

# Test 3: Essential tools are installed
echo ""
echo "Test 3: Essential tools availability"

ESSENTIAL_TOOLS=("git" "curl" "wget" "stow")
MISSING_TOOLS=()

for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "  ✓ $tool: $(command -v $tool)"
    else
        echo -e "  ${RED}✗ $tool: not found${NC}"
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${RED}ERROR: Missing essential tools: ${MISSING_TOOLS[*]}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All essential tools are installed${NC}"

# Test 4: Sudo access (if needed)
echo ""
echo "Test 4: Privilege escalation"

if [ "$EUID" -eq 0 ]; then
    echo "✓ Running as root, no sudo needed"
elif sudo -n true 2>/dev/null; then
    echo -e "${GREEN}✓ Passwordless sudo is configured${NC}"
elif sudo -v 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Sudo requires password (interactive environments only)${NC}"
else
    echo -e "${YELLOW}⚠️  Sudo not available or not configured${NC}"
fi

# Test 5: Package repository access
echo ""
echo "Test 5: Package repository connectivity"

case "$PM" in
    apt-get)
        if sudo apt-get update -qq 2>/dev/null; then
            echo -e "${GREEN}✓ Can access package repositories${NC}"
        else
            echo -e "${YELLOW}⚠️  Package repository update had issues (may be transient)${NC}"
        fi
        ;;

    dnf)
        if sudo dnf check-update -q 2>/dev/null; then
            echo -e "${GREEN}✓ Can access package repositories${NC}"
        else
            echo -e "${YELLOW}⚠️  Package repository check had issues (may be transient)${NC}"
        fi
        ;;

    yum)
        if sudo yum check-update -q 2>/dev/null; then
            echo -e "${GREEN}✓ Can access package repositories${NC}"
        else
            echo -e "${YELLOW}⚠️  Package repository check had issues (may be transient)${NC}"
        fi
        ;;

    pacman)
        if sudo pacman -Sy &> /dev/null; then
            echo -e "${GREEN}✓ Can access package repositories${NC}"
        else
            echo -e "${YELLOW}⚠️  Package repository sync had issues (may be transient)${NC}"
        fi
        ;;

    apk)
        if sudo apk update &> /dev/null; then
            echo -e "${GREEN}✓ Can access package repositories${NC}"
        else
            echo -e "${YELLOW}⚠️  Package repository update had issues (may be transient)${NC}"
        fi
        ;;
esac

echo ""
echo -e "${GREEN}All package manager tests passed!${NC}"
exit 0
