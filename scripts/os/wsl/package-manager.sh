#!/usr/bin/env bash

# WSL Package Manager Implementation
# Extends the Linux package manager with WSL-specific functionality
#
# Key differences from pure Linux:
# - Configures Windows interop settings
# - Sets up wsl.conf for optimal performance
# - Handles Windows executable access
# - Integrates with Windows credential manager

# ============================================================================
# Source Base Linux Implementation
# ============================================================================

_WSL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_WSL_DIR/../linux/package-manager.sh"

# ============================================================================
# WSL Detection
# ============================================================================

is_wsl() {
    grep -qi "microsoft" /proc/version 2>/dev/null
}

is_wsl2() {
    # WSL2 has /run/WSL directory
    [[ -d "/run/WSL" ]] && return 0

    # Alternative: check kernel version
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
        # WSL2 kernel versions are typically 5.x+
        local kernel_major
        kernel_major=$(uname -r | cut -d. -f1)
        [[ "$kernel_major" -ge 5 ]] && return 0
    fi

    return 1
}

# ============================================================================
# WSL Configuration
# ============================================================================

# Get Windows username
get_windows_username() {
    if [[ -n "${WIN_USER:-}" ]]; then
        echo "$WIN_USER"
        return
    fi

    # Try to get from cmd.exe
    local win_user
    win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
    if [[ -n "$win_user" ]]; then
        echo "$win_user"
        return
    fi

    # Fallback: current Linux username
    echo "$USER"
}

# Get Windows home directory path in WSL format
get_windows_home() {
    local win_user
    win_user=$(get_windows_username)
    echo "/mnt/c/Users/$win_user"
}

# Configure /etc/wsl.conf for optimal settings
configure_wsl_conf() {
    local wsl_conf="/etc/wsl.conf"

    if [[ -f "$wsl_conf" ]]; then
        log_verbose "wsl.conf already exists, checking settings..."

        # Check if systemd is enabled
        if grep -q "systemd=true" "$wsl_conf"; then
            log_verbose "systemd already enabled in wsl.conf"
        else
            print_warning "systemd not enabled in wsl.conf"
            print_warning "Add '[boot]\nsystemd=true' to enable systemd"
        fi
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would create /etc/wsl.conf"
        return 0
    fi

    if [[ "${HAS_SUDO:-false}" != "true" ]]; then
        print_warning "Cannot create wsl.conf without sudo"
        return 1
    fi

    print_step "Creating /etc/wsl.conf..."

    sudo tee "$wsl_conf" >/dev/null <<'EOF'
# WSL Configuration
# Documentation: https://docs.microsoft.com/en-us/windows/wsl/wsl-config

[boot]
# Enable systemd (requires WSL 0.67.6 or later)
systemd=true

[interop]
# Enable Windows interop
enabled=true
# Don't add Windows PATH to Linux PATH (cleaner environment)
appendWindowsPath=false

[automount]
# Enable automatic mounting of Windows drives
enabled=true
# Mount with metadata support for proper permissions
options="metadata,umask=22,fmask=11"
# Mount point
root=/mnt/

[network]
# Generate /etc/hosts
generateHosts=true
# Generate /etc/resolv.conf
generateResolvConf=true

[user]
# Default user (uncomment and set your username)
# default=username
EOF

    print_success "Created /etc/wsl.conf"
    print_warning "Restart WSL for changes to take effect: wsl --shutdown"
}

# Create symlinks to Windows folders
create_windows_symlinks() {
    local win_home
    win_home=$(get_windows_home)

    # Define symlinks: source (Windows) -> target (WSL home)
    local -A symlinks=(
        ["$win_home/Documents/Obsidian"]="$HOME/obsidian"
        ["$win_home/Documents/PokerData"]="$HOME/poker-data"
        ["$win_home/Downloads"]="$HOME/downloads-win"
    )

    for source in "${!symlinks[@]}"; do
        local target="${symlinks[$source]}"

        if [[ -L "$target" ]]; then
            log_verbose "Symlink already exists: $target"
            continue
        fi

        if [[ -e "$target" ]]; then
            print_warning "Target exists but is not a symlink: $target"
            continue
        fi

        if [[ ! -d "$source" ]]; then
            print_warning "Windows folder does not exist: $source"
            continue
        fi

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            print_warning "DRY RUN: Would create symlink $target -> $source"
            continue
        fi

        ln -sf "$source" "$target"
        print_success "Created symlink: $target -> $source"
    done
}

# Configure Git credential manager to use Windows
configure_git_credential_manager() {
    local win_home
    win_home=$(get_windows_home)
    local gcm_path="$win_home/AppData/Local/Programs/Git/mingw64/bin/git-credential-manager.exe"

    # Alternative paths for Git credential manager
    local alt_paths=(
        "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe"
        "/mnt/c/Program Files (x86)/Git/mingw64/bin/git-credential-manager.exe"
    )

    # Find credential manager
    local found_gcm=""
    if [[ -f "$gcm_path" ]]; then
        found_gcm="$gcm_path"
    else
        for path in "${alt_paths[@]}"; do
            if [[ -f "$path" ]]; then
                found_gcm="$path"
                break
            fi
        done
    fi

    if [[ -z "$found_gcm" ]]; then
        print_warning "Windows Git Credential Manager not found"
        print_warning "Install Git for Windows or use SSH keys instead"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would configure git credential.helper"
        return 0
    fi

    git config --global credential.helper "$found_gcm"
    print_success "Git configured to use Windows Credential Manager"
}

# ============================================================================
# WSL-Enhanced Package Manager Interface
# ============================================================================

# Override pm_init to add WSL-specific setup
# Save the original Linux pm_init before overriding it.
# Using eval + declare -f renames the existing function so bash doesn't
# resolve pm_init to the (not yet defined) WSL override at call time.
eval "$(declare -f pm_init | sed '1s/pm_init/_linux_pm_init/')"

pm_init() {
    # Call original Linux pm_init (saved above)
    _linux_pm_init

    # Add WSL-specific initialization
    if is_wsl; then
        export IS_WSL=true
        export IS_WSL2=$(is_wsl2 && echo "true" || echo "false")
        export WIN_HOME=$(get_windows_home)
        export WIN_USER=$(get_windows_username)

        log "WSL detected (WSL2: $IS_WSL2)"
        log "Windows home: $WIN_HOME"
    fi

    return 0
}

# WSL-specific post-install setup
wsl_post_install() {
    if [[ "${IS_WSL:-false}" != "true" ]]; then
        return 0
    fi

    print_header "WSL-Specific Configuration"

    # Configure wsl.conf
    configure_wsl_conf

    # Create Windows folder symlinks
    create_windows_symlinks

    # Configure Git credential manager
    configure_git_credential_manager

    # Install wslu utilities if not present
    if ! command_exists wslview; then
        print_step "Installing wslu (WSL utilities)..."
        pm_install wslu 2>/dev/null || print_warning "wslu not available in repos"
    fi
}

# ============================================================================
# WSL-Specific Utilities
# ============================================================================

# Open URL/file in Windows default browser/app
wsl_open() {
    if command_exists wslview; then
        wslview "$@"
    else
        # Fallback to explorer.exe
        explorer.exe "$@" 2>/dev/null
    fi
}

# Copy to Windows clipboard
wsl_clip() {
    clip.exe
}

# Paste from Windows clipboard
wsl_paste() {
    powershell.exe -Command "Get-Clipboard"
}

# Run Windows executable from WSL
wsl_run() {
    local exe="$1"
    shift

    # If it's a full path, run directly
    if [[ "$exe" == /mnt/* ]]; then
        "$exe" "$@"
        return
    fi

    # Search in common Windows locations
    local win_home
    win_home=$(get_windows_home)

    local search_paths=(
        "/mnt/c/Program Files"
        "/mnt/c/Program Files (x86)"
        "$win_home/AppData/Local/Programs"
        "$win_home/AppData/Local"
    )

    for base in "${search_paths[@]}"; do
        local found
        found=$(find "$base" -maxdepth 3 -name "$exe" -type f 2>/dev/null | head -1)
        if [[ -n "$found" ]]; then
            "$found" "$@"
            return
        fi
    done

    print_error "Windows executable not found: $exe"
    return 1
}

# ============================================================================
# Package Name Mapping Overrides for WSL
# ============================================================================

# WSL can use both apt packages AND Windows executables
# Override to handle special cases
_wsl_map_package() {
    local generic=$1

    case "$generic" in
    # These tools can use Windows versions via interop
    docker)
        # Use Docker Desktop from Windows if available
        if [[ -S "/mnt/wsl/docker-desktop/docker.sock" ]]; then
            echo "SKIP:docker (using Docker Desktop)"
            return 0
        fi
        echo "docker.io"
        ;;
    *)
        # Fall through to Linux mapping
        pm_map_package_name "$generic"
        ;;
    esac
}

log_verbose "WSL package manager module loaded"
