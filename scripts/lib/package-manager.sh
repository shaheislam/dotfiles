#!/usr/bin/env bash

# package-manager.sh - Abstract package manager interface
# Defines the common interface that OS-specific implementations must provide

# Source common utilities
# shellcheck source=./common.sh
source "$SCRIPT_DIR/lib/common.sh"

# ============================================================================
# Abstract Interface - Must be implemented by OS-specific modules
# ============================================================================

# pm_init() - Initialize package manager (detect distro, check permissions)
# pm_update() - Update package cache/repositories
# pm_install() - Install a single package
# pm_install_batch() - Install multiple packages
# pm_is_installed() - Check if package is installed
# pm_search() - Search for package
# pm_remove() - Remove package
# pm_cleanup() - Clean package manager cache
# pm_map_package_name() - Map generic name to OS-specific name

# ============================================================================
# OS-Specific Module Loading
# ============================================================================

load_package_manager() {
    local os=${DETECTED_OS:-$(detect_os)}
    local pm_module="$SCRIPT_DIR/os/$os/package-manager.sh"

    if [[ ! -f "$pm_module" ]]; then
        print_error "Package manager module not found for OS: $os"
        print_error "Expected: $pm_module"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$pm_module"

    # Initialize the package manager
    if ! pm_init; then
        print_error "Failed to initialize package manager"
        return 1
    fi

    print_success "Package manager initialized: $os"
    log "Package manager module loaded: $pm_module"
}

# ============================================================================
# High-Level Package Operations
# ============================================================================

install_package_group() {
    local group_name=$1
    shift
    local packages=("$@")

    print_step "Installing $group_name packages..."
    echo ""

    local to_install=()
    local skipped=()

    # First pass: check what's already installed
    for package in "${packages[@]}"; do
        if pm_is_installed "$package"; then
            skipped+=("$package")
            print_success "Already installed: $package"
        else
            to_install+=("$package")
        fi
    done

    local installed=()
    local failed=()

    # Batch install missing packages (single brew invocation resolves deps once)
    if [[ ${#to_install[@]} -gt 0 ]] && declare -f pm_install_batch >/dev/null 2>&1; then
        if pm_install_batch "${to_install[@]}"; then
            installed=("${to_install[@]}")
            for pkg in "${to_install[@]}"; do
                print_success "Installed: $pkg"
            done
        else
            # Batch failed — fall back to individual installs for granular error reporting
            for package in "${to_install[@]}"; do
                if pm_install "$package"; then
                    installed+=("$package")
                    print_success "Installed: $package"
                else
                    failed+=("$package")
                    print_warning "Failed to install: $package"
                fi
            done
        fi
    else
        # No batch function available — install individually
        for package in "${to_install[@]}"; do
            if pm_install "$package"; then
                installed+=("$package")
                print_success "Installed: $package"
            else
                failed+=("$package")
                print_warning "Failed to install: $package"
            fi
        done
    fi

    # Phase summary
    echo ""
    print_step "[$group_name] Summary:"
    echo "  • Newly installed: ${#installed[@]}"
    echo "  • Already installed: ${#skipped[@]}"
    if [[ ${#failed[@]} -gt 0 ]]; then
        echo "  • Failed: ${#failed[@]}"
    fi
    echo ""

    if [[ ${#installed[@]} -gt 0 ]]; then
        log "Installed ${#installed[@]} packages: ${installed[*]}"
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        log "Failed to install ${#failed[@]} packages: ${failed[*]}"
        # In Docker/CI environments (FORCE_ONLINE=true), don't fail on package errors
        # This allows setup to continue even if OS-specific packages (like mas) fail
        if [[ "${FORCE_ONLINE:-false}" != "true" ]]; then
            return 1
        fi
    fi

    return 0
}

ensure_package_installed() {
    local package=$1
    local description=${2:-$package}

    if pm_is_installed "$package"; then
        log_verbose "$description is already installed"
        return 0
    fi

    print_step "Installing $description..."

    if pm_install "$package"; then
        print_success "Installed: $description"
        return 0
    else
        print_error "Failed to install: $description"
        return 1
    fi
}

# ============================================================================
# Package Lists from Profiles
# ============================================================================

get_package_list_from_profile() {
    local profile=$1
    local section=$2

    local profile_file="$SCRIPT_DIR/profiles/${profile}.conf"

    if [[ ! -f "$profile_file" ]]; then
        print_error "Profile not found: $profile"
        return 1
    fi

    # Parse INI-style config for enabled packages in section
    local in_section=false
    local packages=()

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

        # Check for section header
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # If in target section, parse key=value
        if [[ "$in_section" == "true" && "$line" =~ ^([^=]+)=(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # If value is "true", add package to list
            if [[ "$value" == "true" ]]; then
                packages+=("$key")
            fi
        fi
    done <"$profile_file"

    # Return packages as space-separated string
    echo "${packages[*]}"
}

install_packages_from_profile() {
    local profile=$1
    local section=$2

    local packages=$(get_package_list_from_profile "$profile" "$section")

    if [[ -z "$packages" ]]; then
        print_step "No packages configured for [$section]"
        log_verbose "Skipping empty section: $section"
        return 0
    fi

    # Show package count
    local package_array=($packages)
    print_step "Found ${#package_array[@]} package(s) in [$section] to process"
    log_verbose "Package list: ${packages}"
    echo ""

    install_package_group "$section" $packages
}

# ============================================================================
# Validation
# ============================================================================

validate_package_manager() {
    local required_functions=(
        "pm_init"
        "pm_update"
        "pm_install"
        "pm_is_installed"
        "pm_map_package_name"
    )

    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" >/dev/null; then
            print_error "Required function not implemented: $func"
            return 1
        fi
    done

    log_verbose "Package manager interface validation passed"
    return 0
}

# ============================================================================
# Initialize
# ============================================================================

init_package_manager() {
    log "Initializing package manager system..."

    # Load OS-specific package manager
    if ! load_package_manager; then
        return 1
    fi

    # Validate implementation
    if ! validate_package_manager; then
        return 1
    fi

    log "Package manager system initialized"
    return 0
}

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_package_manager
fi
