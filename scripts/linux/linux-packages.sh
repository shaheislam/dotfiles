#!/usr/bin/env bash

# linux-packages.sh - Distribution-agnostic package management for Linux dotfiles setup
# Provides abstraction layer for different package managers (apt, yum, dnf)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
DISTRO=""
DISTRO_VERSION=""
PACKAGE_MANAGER=""
HAS_SUDO=false
USE_LINUXBREW=false

# ============================================================================
# Distribution Detection
# ============================================================================

detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID

        echo -e "${BLUE}Detected distribution: $NAME $VERSION${NC}"

        case $DISTRO in
            ubuntu|debian|pop)
                PACKAGE_MANAGER="apt"
                ;;
            amzn|amazonlinux)
                PACKAGE_MANAGER="yum"
                if command -v dnf &> /dev/null; then
                    PACKAGE_MANAGER="dnf"
                fi
                ;;
            rhel|centos|rocky|almalinux|fedora)
                PACKAGE_MANAGER="dnf"
                if ! command -v dnf &> /dev/null; then
                    PACKAGE_MANAGER="yum"
                fi
                ;;
            arch|manjaro)
                PACKAGE_MANAGER="pacman"
                ;;
            opensuse*|sles)
                PACKAGE_MANAGER="zypper"
                ;;
            *)
                echo -e "${YELLOW}Unknown distribution: $DISTRO${NC}"
                echo -e "${YELLOW}Will attempt to detect package manager...${NC}"
                detect_package_manager_fallback
                ;;
        esac
    else
        echo -e "${YELLOW}Cannot detect distribution, trying fallback detection${NC}"
        detect_package_manager_fallback
    fi
}

detect_package_manager_fallback() {
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
    elif command -v zypper &> /dev/null; then
        PACKAGE_MANAGER="zypper"
    else
        echo -e "${RED}No supported package manager found${NC}"
        return 1
    fi
}

# ============================================================================
# Sudo Detection
# ============================================================================

check_sudo() {
    if sudo -n true 2>/dev/null; then
        HAS_SUDO=true
        echo -e "${GREEN}Sudo access detected${NC}"
    else
        echo -e "${YELLOW}Limited or no sudo access${NC}"
        HAS_SUDO=false
    fi
}

# ============================================================================
# Package Name Mapping
# ============================================================================

# Map generic package names to distro-specific names
map_package_name() {
    local generic_name=$1
    local distro_name=""

    case $PACKAGE_MANAGER in
        apt)
            case $generic_name in
                build-essential) distro_name="build-essential" ;;
                fd) distro_name="fd-find" ;;
                ripgrep) distro_name="ripgrep" ;;
                bat) distro_name="bat" ;;
                development-tools) distro_name="build-essential" ;;
                python3-devel) distro_name="python3-dev" ;;
                python311) distro_name="python3.11" ;;
                nodejs) distro_name="nodejs" ;;
                golang) distro_name="golang-go" ;;
                *) distro_name=$generic_name ;;
            esac
            ;;
        yum|dnf)
            case $generic_name in
                build-essential) distro_name="@development" ;;
                fd) distro_name="fd-find" ;;
                ripgrep) distro_name="ripgrep" ;;
                bat) distro_name="bat" ;;
                development-tools) distro_name="@development" ;;
                python3-devel) distro_name="python3-devel" ;;
                python311) distro_name="python3.11" ;;
                nodejs) distro_name="nodejs" ;;
                golang) distro_name="golang" ;;
                *) distro_name=$generic_name ;;
            esac
            ;;
        pacman)
            case $generic_name in
                build-essential) distro_name="base-devel" ;;
                fd) distro_name="fd" ;;
                ripgrep) distro_name="ripgrep" ;;
                bat) distro_name="bat" ;;
                development-tools) distro_name="base-devel" ;;
                *) distro_name=$generic_name ;;
            esac
            ;;
    esac

    echo "$distro_name"
}

# ============================================================================
# Package Installation Functions
# ============================================================================

update_package_cache() {
    echo -e "${BLUE}Updating package cache...${NC}"

    if [[ $HAS_SUDO == true ]]; then
        case $PACKAGE_MANAGER in
            apt)
                sudo apt-get update -y
                ;;
            yum|dnf)
                sudo $PACKAGE_MANAGER check-update || true
                ;;
            pacman)
                sudo pacman -Sy
                ;;
        esac
    else
        echo -e "${YELLOW}Skipping package cache update (no sudo)${NC}"
    fi
}

install_package() {
    local package=$1
    local mapped_package=$(map_package_name "$package")

    echo -e "${BLUE}Installing: $mapped_package${NC}"

    if [[ $HAS_SUDO == true ]]; then
        case $PACKAGE_MANAGER in
            apt)
                sudo apt-get install -y "$mapped_package" 2>&1 | grep -v "is already the newest version" || true
                ;;
            yum|dnf)
                sudo $PACKAGE_MANAGER install -y "$mapped_package"
                ;;
            pacman)
                sudo pacman -S --noconfirm "$mapped_package"
                ;;
        esac
    elif [[ $USE_LINUXBREW == true ]]; then
        brew install "$package"
    else
        echo -e "${RED}Cannot install $package (no sudo or Linuxbrew)${NC}"
        return 1
    fi
}

install_packages() {
    local packages=("$@")

    for package in "${packages[@]}"; do
        if ! install_package "$package"; then
            echo -e "${YELLOW}Failed to install: $package${NC}"
        fi
    done
}

check_package_installed() {
    local package=$1

    case $PACKAGE_MANAGER in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii" && return 0 || return 1
            ;;
        yum|dnf)
            $PACKAGE_MANAGER list installed "$package" &>/dev/null && return 0 || return 1
            ;;
        pacman)
            pacman -Q "$package" &>/dev/null && return 0 || return 1
            ;;
    esac
}

# ============================================================================
# Linuxbrew Setup (Fallback for no-sudo environments)
# ============================================================================

setup_linuxbrew() {
    if command -v brew &> /dev/null; then
        echo -e "${GREEN}Linuxbrew already installed${NC}"
        USE_LINUXBREW=true
        return 0
    fi

    echo -e "${BLUE}Installing Linuxbrew (Homebrew for Linux)...${NC}"

    if ! command -v git &> /dev/null; then
        echo -e "${RED}Git is required to install Linuxbrew${NC}"
        echo -e "${YELLOW}Please install git using your system package manager${NC}"
        return 1
    fi

    # Install Linuxbrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to PATH
    if [[ -d /home/linuxbrew/.linuxbrew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        USE_LINUXBREW=true
        echo -e "${GREEN}Linuxbrew installed successfully${NC}"
    else
        echo -e "${RED}Linuxbrew installation failed${NC}"
        return 1
    fi
}

# ============================================================================
# Core Package Groups
# ============================================================================

install_core_packages() {
    echo -e "${BLUE}Installing core packages...${NC}"

    local core_packages=(
        git
        curl
        wget
        stow
        unzip
        tar
        gzip
    )

    if [[ $HAS_SUDO == true ]]; then
        core_packages+=(build-essential)
    fi

    install_packages "${core_packages[@]}"
}

install_shell_packages() {
    echo -e "${BLUE}Installing shell packages...${NC}"

    local shell_packages=(
        fish
        zsh
    )

    install_packages "${shell_packages[@]}"
}

install_editor_packages() {
    echo -e "${BLUE}Installing editor packages...${NC}"

    # Check if neovim is available in repos
    if check_package_available "neovim"; then
        install_package "neovim"
    else
        echo -e "${YELLOW}Neovim not available in repos, will need to build from source${NC}"
    fi
}

install_cli_tools() {
    echo -e "${BLUE}Installing CLI tools...${NC}"

    local cli_tools=(
        ripgrep
        fd
        fzf
        bat
        tmux
        htop
        jq
    )

    install_packages "${cli_tools[@]}"
}

install_development_tools() {
    echo -e "${BLUE}Installing development tools...${NC}"

    local dev_packages=()

    # Add Python development tools
    if [[ $HAS_SUDO == true ]]; then
        dev_packages+=(python3-devel)
    fi

    # Add other dev tools
    dev_packages+=(
        python3
        python3-pip
    )

    install_packages "${dev_packages[@]}"
}

check_package_available() {
    local package=$1
    local mapped_package=$(map_package_name "$package")

    case $PACKAGE_MANAGER in
        apt)
            apt-cache show "$mapped_package" &>/dev/null && return 0 || return 1
            ;;
        yum|dnf)
            $PACKAGE_MANAGER info "$mapped_package" &>/dev/null && return 0 || return 1
            ;;
        pacman)
            pacman -Si "$mapped_package" &>/dev/null && return 0 || return 1
            ;;
    esac
}

# ============================================================================
# Main Initialization
# ============================================================================

init_package_manager() {
    echo -e "${BLUE}Initializing package manager...${NC}"
    detect_distribution
    check_sudo

    if [[ $HAS_SUDO == false ]]; then
        echo -e "${YELLOW}No sudo access detected${NC}"
        echo -e "${YELLOW}Will use Linuxbrew for package installation${NC}"
        setup_linuxbrew
    fi

    echo -e "${GREEN}Package manager: $PACKAGE_MANAGER${NC}"
    echo -e "${GREEN}Distribution: $DISTRO${NC}"
}

# ============================================================================
# Export Functions for Use in Other Scripts
# ============================================================================

# If this script is sourced, initialize and make functions available
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_package_manager
fi
