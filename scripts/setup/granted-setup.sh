#!/bin/bash
# Granted Setup and Management Helper Script
# Provides utilities for managing Granted AWS profile colors, icons, and configurations

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration paths
GRANTED_CONFIG_DIR="$HOME/.granted"
FIREFOX_PROFILES_FILE="$GRANTED_CONFIG_DIR/firefox-profiles"
DOTFILES_CONFIG_DIR="$HOME/dotfiles/.granted"

# Available colors and icons
COLORS=(blue turquoise green yellow orange red pink purple)
ICONS=(fingerprint briefcase dollar cart circle gift vacation food fruit pet tree chill)

print_usage() {
    cat << EOF
Granted Setup and Management Helper

Usage: $0 [command] [options]

Commands:
    setup                       - Initial setup and configuration
    set-profile-color PROFILE COLOR ICON - Set Firefox color/icon for profile
    list-profiles              - List configured Firefox profiles
    list-colors                - Show available colors and icons
    test-config               - Test Granted configuration
    backup-config             - Backup current configuration
    restore-config            - Restore configuration from dotfiles
    help                      - Show this help message

Examples:
    $0 setup
    $0 set-profile-color production red briefcase
    $0 set-profile-color development green tree
    $0 list-profiles
    $0 test-config

Available Colors: $(printf '%s ' "${COLORS[@]}")
Available Icons:  $(printf '%s ' "${ICONS[@]}")
EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

validate_color() {
    local color="$1"
    for valid_color in "${COLORS[@]}"; do
        if [[ "$color" == "$valid_color" ]]; then
            return 0
        fi
    done
    return 1
}

validate_icon() {
    local icon="$1"
    for valid_icon in "${ICONS[@]}"; do
        if [[ "$icon" == "$valid_icon" ]]; then
            return 0
        fi
    done
    return 1
}

setup_granted() {
    log_info "Setting up Granted configuration..."

    # Check if Granted is installed
    if ! command -v granted &> /dev/null; then
        log_error "Granted is not installed. Please install it first with: brew install granted"
        exit 1
    fi

    # Create config directory
    mkdir -p "$GRANTED_CONFIG_DIR"

    # Copy configuration files from dotfiles
    if [[ -f "$DOTFILES_CONFIG_DIR/config" ]]; then
        log_info "Installing Granted configuration..."
        cp "$DOTFILES_CONFIG_DIR/config" "$GRANTED_CONFIG_DIR/config"
        log_success "Granted configuration installed"
    else
        log_warning "Granted config file not found in dotfiles"
    fi

    if [[ -f "$DOTFILES_CONFIG_DIR/firefox-profiles" ]]; then
        log_info "Installing Firefox profiles configuration..."
        cp "$DOTFILES_CONFIG_DIR/firefox-profiles" "$FIREFOX_PROFILES_FILE"
        log_success "Firefox profiles configuration installed"
    else
        log_warning "Firefox profiles config not found in dotfiles"
    fi

    # Generate shell completions
    if command -v fish &> /dev/null; then
        log_info "Generating Fish shell completions..."
        mkdir -p "$HOME/.config/fish/completions"
        granted completion --shell fish > "$HOME/.config/fish/completions/granted.fish" 2>/dev/null || true
        log_success "Fish completions generated"
    fi

    if command -v zsh &> /dev/null; then
        log_info "Zsh completions will be loaded automatically"
    fi

    log_success "Granted setup complete!"
    log_info "You can now use 'assume <profile>' to switch AWS profiles"
    log_info "Firefox profiles will use colors and icons as configured"
}

set_profile_color() {
    local profile="$1"
    local color="$2"
    local icon="$3"

    if [[ -z "$profile" || -z "$color" || -z "$icon" ]]; then
        log_error "Usage: set-profile-color PROFILE COLOR ICON"
        return 1
    fi

    if ! validate_color "$color"; then
        log_error "Invalid color: $color"
        log_info "Available colors: $(printf '%s ' "${COLORS[@]}")"
        return 1
    fi

    if ! validate_icon "$icon"; then
        log_error "Invalid icon: $icon"
        log_info "Available icons: $(printf '%s ' "${ICONS[@]}")"
        return 1
    fi

    # Ensure Firefox profiles file exists
    if [[ ! -f "$FIREFOX_PROFILES_FILE" ]]; then
        log_warning "Firefox profiles file not found, creating..."
        mkdir -p "$GRANTED_CONFIG_DIR"
        touch "$FIREFOX_PROFILES_FILE"
    fi

    # Remove existing entry for this profile
    grep -v "^$profile=" "$FIREFOX_PROFILES_FILE" > "$FIREFOX_PROFILES_FILE.tmp" 2>/dev/null || true

    # Add new entry
    echo "$profile=$color:$icon" >> "$FIREFOX_PROFILES_FILE.tmp"

    # Sort and replace
    sort "$FIREFOX_PROFILES_FILE.tmp" > "$FIREFOX_PROFILES_FILE"
    rm "$FIREFOX_PROFILES_FILE.tmp"

    log_success "Set $profile to use $color color with $icon icon"
}

list_profiles() {
    log_info "Configured Firefox profiles:"

    if [[ ! -f "$FIREFOX_PROFILES_FILE" ]]; then
        log_warning "No Firefox profiles configuration found"
        return 1
    fi

    while IFS='=' read -r profile config; do
        if [[ -n "$profile" && ! "$profile" =~ ^# ]]; then
            IFS=':' read -r color icon <<< "$config"
            printf "  %-20s %s%s%s (icon: %s)\n" "$profile" "$color" "$color" "${NC}" "$icon"
        fi
    done < "$FIREFOX_PROFILES_FILE"
}

list_colors() {
    log_info "Available Firefox colors and icons:"
    echo
    echo "Colors:"
    for color in "${COLORS[@]}"; do
        printf "  %s\n" "$color"
    done
    echo
    echo "Icons:"
    for icon in "${ICONS[@]}"; do
        printf "  %s\n" "$icon"
    done
}

test_config() {
    log_info "Testing Granted configuration..."

    # Check if Granted is installed
    if ! command -v granted &> /dev/null; then
        log_error "Granted is not installed"
        return 1
    fi

    log_success "Granted is installed: $(granted --version)"

    # Check config files
    if [[ -f "$GRANTED_CONFIG_DIR/config" ]]; then
        log_success "Main configuration file exists"
    else
        log_warning "Main configuration file not found"
    fi

    if [[ -f "$FIREFOX_PROFILES_FILE" ]]; then
        log_success "Firefox profiles configuration exists"
        local profile_count=$(grep -c "^[^#]" "$FIREFOX_PROFILES_FILE" 2>/dev/null || echo 0)
        log_info "Configured profiles: $profile_count"
    else
        log_warning "Firefox profiles configuration not found"
    fi

    # Test AWS profiles
    log_info "Available AWS profiles:"
    if granted profiles list --no-color 2>/dev/null | head -5; then
        log_success "AWS profiles accessible"
    else
        log_warning "No AWS profiles found or error accessing profiles"
    fi

    # Check shell completions
    if [[ -f "$HOME/.config/fish/completions/granted.fish" ]]; then
        log_success "Fish completions installed"
    else
        log_warning "Fish completions not found"
    fi
}

backup_config() {
    local backup_dir="$HOME/.granted.backup.$(date +%Y%m%d-%H%M%S)"

    if [[ -d "$GRANTED_CONFIG_DIR" ]]; then
        log_info "Backing up Granted configuration to $backup_dir"
        cp -r "$GRANTED_CONFIG_DIR" "$backup_dir"
        log_success "Configuration backed up to $backup_dir"
    else
        log_warning "No configuration to backup"
    fi
}

restore_config() {
    log_info "Restoring Granted configuration from dotfiles..."
    backup_config
    setup_granted
}

# Main script logic
case "${1:-help}" in
    setup)
        setup_granted
        ;;
    set-profile-color)
        set_profile_color "$2" "$3" "$4"
        ;;
    list-profiles)
        list_profiles
        ;;
    list-colors)
        list_colors
        ;;
    test-config)
        test_config
        ;;
    backup-config)
        backup_config
        ;;
    restore-config)
        restore_config
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo
        print_usage
        exit 1
        ;;
esac
