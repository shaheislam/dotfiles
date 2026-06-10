#!/usr/bin/env bash

# common.sh - Shared utility functions for cross-platform dotfiles setup
# Used by both macOS and Linux implementations

# ============================================================================
# Color Definitions
# ============================================================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# ============================================================================
# Global Variables
# ============================================================================

export DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LOG_DIR="${LOG_DIR:-$HOME/.dotfiles-setup/logs}"
export LOG_FILE="${LOG_FILE:-$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log}"
export STATE_DIR="${STATE_DIR:-$HOME/.dotfiles-setup/state}"

# Create necessary directories
mkdir -p "$LOG_DIR" "$STATE_DIR"

# ============================================================================
# Output Functions
# ============================================================================

print_header() {
    echo -e "\n${CYAN}========================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}========================================${NC}\n" | tee -a "$LOG_FILE"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

log_verbose() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${MAGENTA}[VERBOSE] $1${NC}" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE"
    fi
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"
}

# ============================================================================
# OS Detection
# ============================================================================

detect_os() {
    local os_type
    os_type=$(uname -s)

    case "$os_type" in
    Darwin*)
        echo "macos"
        ;;
    Linux*)
        # Check for WSL (Windows Subsystem for Linux)
        if grep -qi "microsoft" /proc/version 2>/dev/null; then
            echo "wsl"
        else
            echo "linux"
        fi
        ;;
    MINGW* | MSYS* | CYGWIN*)
        echo "windows"
        ;;
    *)
        echo "unknown"
        ;;
    esac
}

# Detect WSL version (1 or 2)
detect_wsl_version() {
    if ! grep -qi "microsoft" /proc/version 2>/dev/null; then
        echo "none"
        return
    fi

    # WSL2 has /run/WSL directory
    if [[ -d "/run/WSL" ]]; then
        echo "wsl2"
        return
    fi

    # WSL2 kernel versions are typically 5.x+
    local kernel_major
    kernel_major=$(uname -r | cut -d. -f1)
    if [[ "$kernel_major" -ge 5 ]]; then
        echo "wsl2"
    else
        echo "wsl1"
    fi
}

# Get Windows home directory path (for WSL)
get_windows_home() {
    if [[ "$(detect_os)" != "wsl" ]]; then
        echo ""
        return
    fi

    # Try to get from cmd.exe
    local win_user
    win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
    if [[ -n "$win_user" ]]; then
        echo "/mnt/c/Users/$win_user"
    else
        # Fallback: use current Linux username
        echo "/mnt/c/Users/$USER"
    fi
}

detect_linux_distro() {
    if [[ ! -f /etc/os-release ]]; then
        echo "unknown"
        return 1
    fi

    . /etc/os-release
    echo "$ID"
}

detect_os_version() {
    local os
    os=$(detect_os)

    case "$os" in
    macos)
        sw_vers -productVersion
        ;;
    linux)
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            echo "$VERSION_ID"
        else
            echo "unknown"
        fi
        ;;
    *)
        echo "unknown"
        ;;
    esac
}

# ============================================================================
# Architecture Detection
# ============================================================================

detect_arch() {
    local arch
    arch=$(uname -m)

    case "$arch" in
    x86_64 | amd64)
        echo "x86_64"
        ;;
    aarch64 | arm64)
        echo "arm64"
        ;;
    armv7l)
        echo "armv7"
        ;;
    *)
        echo "$arch"
        ;;
    esac
}

get_arch_suffix() {
    local arch os
    arch=$(detect_arch)
    os=$(detect_os)

    case "$os" in
    macos)
        case "$arch" in
        x86_64) echo "x86_64-apple-darwin" ;;
        arm64) echo "aarch64-apple-darwin" ;;
        esac
        ;;
    linux)
        case "$arch" in
        x86_64) echo "x86_64-unknown-linux-gnu" ;;
        arm64) echo "aarch64-unknown-linux-gnu" ;;
        armv7) echo "armv7-unknown-linux-gnueabihf" ;;
        esac
        ;;
    esac
}

# ============================================================================
# Network & Connectivity
# ============================================================================

check_internet() {
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null ||
        ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_github_connectivity() {
    if curl -s --connect-timeout 5 https://github.com >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

detect_installation_mode() {
    # Allow forcing online mode (useful for Docker containers where ping may fail)
    if [[ "${FORCE_ONLINE:-false}" == "true" ]]; then
        echo "online"
    elif [[ -n "${OFFLINE_PACKAGE:-}" ]]; then
        echo "offline"
    elif [[ "${FORCE_OFFLINE:-false}" == "true" ]]; then
        echo "offline"
    elif ! check_internet; then
        print_warning "No internet detected"
        echo "offline"
    else
        echo "online"
    fi
}

# ============================================================================
# System Resources
# ============================================================================

check_disk_space() {
    local required_mb=${1:-500}
    local target_dir=${2:-$HOME}

    local available_mb
    available_mb=$(df -m "$target_dir" | awk 'NR==2 {print $4}')

    if [[ $available_mb -lt $required_mb ]]; then
        print_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi

    log_verbose "Disk space check passed: ${available_mb}MB available"
    return 0
}

get_cpu_cores() {
    local os
    os=$(detect_os)

    case "$os" in
    macos)
        sysctl -n hw.ncpu
        ;;
    linux)
        nproc
        ;;
    *)
        echo "1"
        ;;
    esac
}

# ============================================================================
# Command Availability
# ============================================================================

command_exists() {
    command -v "$1" &>/dev/null
}

run_noninteractive() {
    env CI=1 NONINTERACTIVE=1 "$@" </dev/null
}

run_remote_shell_installer() {
    local shell_cmd=$1
    local url=$2
    local installer status

    installer=$(mktemp "${TMPDIR:-/tmp}/dotfiles-installer.XXXXXX") || return 1
    if curl -fsSL "$url" -o "$installer"; then
        run_noninteractive "$shell_cmd" "$installer"
        status=$?
    else
        status=$?
    fi
    rm -f "$installer"
    return $status
}

require_command() {
    local cmd=$1
    local msg=${2:-"Required command not found: $cmd"}

    if ! command_exists "$cmd"; then
        print_error "$msg"
        return 1
    fi
    return 0
}

check_required_commands() {
    local missing=()

    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing[*]}"
        return 1
    fi

    return 0
}

# ============================================================================
# Sudo Detection
# ============================================================================

check_sudo() {
    if sudo -n true 2>/dev/null; then
        export HAS_SUDO=true
        log_verbose "Sudo access available"
    else
        export HAS_SUDO=false
        log_verbose "No sudo access or requires password"
    fi
}

should_use_sudo() {
    [[ "${NO_SUDO:-false}" != "true" ]]
}

require_sudo() {
    if ! should_use_sudo; then
        print_error "This operation is disabled by --no-sudo"
        return 1
    fi

    if [[ "${HAS_SUDO:-false}" != "true" ]]; then
        print_error "This operation requires sudo access"
        return 1
    fi
    return 0
}

# ============================================================================
# Path Management
# ============================================================================

add_to_path() {
    local path_dir=$1
    local shell_config=$2

    if [[ ! -d "$path_dir" ]]; then
        log_verbose "Path directory does not exist: $path_dir"
        return 1
    fi

    # Check if already in PATH
    if [[ ":$PATH:" == *":$path_dir:"* ]]; then
        log_verbose "Path already includes: $path_dir"
        return 0
    fi

    # Add to shell config
    if [[ -f "$shell_config" ]] && ! grep -q "$path_dir" "$shell_config"; then
        echo "" >>"$shell_config"
        echo "# Added by dotfiles setup" >>"$shell_config"
        echo "export PATH=\"$path_dir:\$PATH\"" >>"$shell_config"
        print_success "Added $path_dir to PATH in $shell_config"
    fi
}

ensure_local_bin_in_path() {
    local local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"

    add_to_path "$local_bin" "$HOME/.bashrc"
    add_to_path "$local_bin" "$HOME/.zshrc"

    # For current session
    export PATH="$local_bin:$PATH"
}

# ============================================================================
# File Operations
# ============================================================================

backup_file() {
    local file=$1
    local backup_suffix=${2:-.backup.$(date +%s)}

    if [[ -e "$file" && ! -L "$file" ]]; then
        local backup="${file}${backup_suffix}"
        mv "$file" "$backup"
        log_verbose "Backed up: $file -> $backup"
        return 0
    fi
    return 1
}

safe_symlink() {
    local source=$1
    local target=$2

    if [[ ! -e "$source" ]]; then
        print_error "Source does not exist: $source"
        return 1
    fi

    # Backup existing file/directory
    backup_file "$target"

    # Create symlink
    ln -sf "$source" "$target"
    log_verbose "Symlinked: $target -> $source"
}

# ============================================================================
# Download & Extraction
# ============================================================================

download_file() {
    local url=$1
    local output=$2
    local max_retries=${3:-3}

    for i in $(seq 1 $max_retries); do
        if curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$output"; then
            log_verbose "Downloaded: $url"
            return 0
        fi

        if [[ $i -lt $max_retries ]]; then
            local wait_time=$((2 ** i))
            print_warning "Download failed, retrying in ${wait_time}s... (attempt $i/$max_retries)"
            sleep $wait_time
        fi
    done

    print_error "Failed to download after $max_retries attempts: $url"
    return 1
}

extract_archive() {
    local archive=$1
    local dest_dir=$2

    case "$archive" in
    *.tar.gz | *.tgz)
        tar xzf "$archive" -C "$dest_dir"
        ;;
    *.tar.bz2 | *.tbz2)
        tar xjf "$archive" -C "$dest_dir"
        ;;
    *.tar.xz | *.txz)
        tar xJf "$archive" -C "$dest_dir"
        ;;
    *.zip)
        unzip -q "$archive" -d "$dest_dir"
        ;;
    *)
        print_error "Unknown archive format: $archive"
        return 1
        ;;
    esac

    log_verbose "Extracted: $archive -> $dest_dir"
}

# ============================================================================
# State Management
# ============================================================================

mark_step_complete() {
    local step_name=$1
    touch "$STATE_DIR/${step_name}.complete"
    log "Marked step complete: $step_name"
}

is_step_complete() {
    local step_name=$1
    if [[ -f "$STATE_DIR/${step_name}.complete" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

clear_state() {
    rm -rf "${STATE_DIR:?}"/*
    log "Cleared all state"
}

# ============================================================================
# Error Handling
# ============================================================================

setup_error_handling() {
    set -euo pipefail

    trap 'handle_error $? $LINENO' ERR
    trap 'cleanup_on_exit' EXIT
}

handle_error() {
    local exit_code=$1
    local line_number=$2

    print_error "Command failed with exit code $exit_code at line $line_number"
    log "Error context: Last command in ${BASH_COMMAND:-unknown}"

    export SETUP_FAILED=true
}

cleanup_on_exit() {
    if [[ "${SETUP_FAILED:-false}" == "true" ]]; then
        print_warning "Setup failed, check log: $LOG_FILE"
    fi
}

# ============================================================================
# Confirmation Prompts
# ============================================================================

confirm() {
    local prompt=$1

    # Skip confirmation if NO_CONFIRM is set
    if [[ "${NO_CONFIRM:-false}" == "true" ]]; then
        return 0
    fi

    # Skip if not interactive
    if [[ ! -t 0 ]]; then
        return 0
    fi

    local yn
    read -p "$(echo -e "${YELLOW}${prompt} [y/N]${NC} ")" yn

    case "$yn" in
    [Yy]*)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

# ============================================================================
# Initialization
# ============================================================================

init_common() {
    # Ensure error handling is set up
    setup_error_handling

    # Detect system information
    DETECTED_OS=$(detect_os)
    DETECTED_ARCH=$(detect_arch)
    DETECTED_MODE=$(detect_installation_mode)
    export DETECTED_OS DETECTED_ARCH DETECTED_MODE

    # Check sudo availability
    check_sudo

    # Ensure ~/.local/bin exists and is in PATH
    ensure_local_bin_in_path

    log "=== Dotfiles Setup Started ==="
    log "OS: $DETECTED_OS"
    log "Architecture: $DETECTED_ARCH"
    log "Mode: $DETECTED_MODE"
    log "Sudo: ${HAS_SUDO:-false}"
}

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_common
fi
