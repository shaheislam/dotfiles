#!/usr/bin/env bash

# setup-mobile-coding.sh - Configure machine for remote mobile development
#
# This script sets up Mosh + Tailscale for secure remote access from mobile devices.
# It is intentionally SEPARATE from setup.sh to avoid installing remote access
# tools on work devices where they could introduce security risks.
#
# Usage:
#   ./scripts/setup-mobile-coding.sh           # Install everything
#   ./scripts/setup-mobile-coding.sh --verbose # With detailed output
#   ./scripts/setup-mobile-coding.sh --uninstall # Remove everything
#   ./scripts/setup-mobile-coding.sh --help    # Show help
#
# What this script does:
#   1. Installs Mosh (mobile-friendly SSH with connection persistence)
#   2. Installs Tailscale (zero-config VPN for secure access)
#   3. Configures SSH with key-only authentication
#   4. Disables system sleep for 24/7 accessibility
#   5. Configures firewall for Mosh UDP ports
#   6. Creates a mobile-optimized tmux session launcher

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific state
MOBILE_STATE_PREFIX="mobile-coding"
VERBOSE="${VERBOSE:-false}"
UNINSTALL=false

# ============================================================================
# Help
# ============================================================================

show_help() {
    cat << EOF
Mobile Coding Setup - Configure remote development from mobile devices

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --verbose       Show detailed output
    --uninstall     Remove Mosh, Tailscale, and restore original settings
    --help          Show this help message

DESCRIPTION:
    This script configures your machine as a remote development server
    accessible from mobile devices via Mosh + Tailscale.

    IMPORTANT: Only run this on PERSONAL devices. Do not run on work
    devices as it could introduce security risks.

WHAT IT INSTALLS:
    - Mosh: Mobile shell with connection persistence
    - Tailscale: Zero-config VPN (no port forwarding needed)

WHAT IT CONFIGURES:
    - SSH: Key-only authentication (more secure, works with 1Password)
    - Sleep: Disabled to keep machine accessible 24/7
    - Firewall: Opens Mosh UDP ports (60000-61000)
    - tmux: Mobile-optimized session launcher

PHONE SETUP (after running this script):
    1. Install Tailscale app, sign in with same account
    2. Install Termius app, create host with Tailscale hostname
    3. Enable Mosh in Termius host settings
    4. Import SSH key from 1Password into Termius
    5. Connect and run: tmux-mobile-session.sh

EOF
}

# ============================================================================
# Argument Parsing
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Preflight Checks
# ============================================================================

preflight_checks() {
    print_header "Preflight Checks"

    # Check OS compatibility
    local os=$(detect_os)
    if [[ "$os" != "macos" && "$os" != "linux" ]]; then
        print_error "Unsupported OS: $os. This script supports macOS and Linux only."
        exit 1
    fi
    print_success "OS detected: $os"

    # Safety confirmation
    if [[ "$UNINSTALL" != "true" ]]; then
        echo ""
        print_warning "SECURITY WARNING"
        echo "This script installs remote access tools (Mosh, Tailscale)."
        echo "Only run this on PERSONAL devices, NOT on work devices."
        echo ""
        if ! confirm "Is this a personal device where you want to enable remote access?"; then
            print_error "Aborted. Do not run this on work devices."
            exit 1
        fi
    fi
}

# ============================================================================
# Uninstall Functions
# ============================================================================

uninstall_all() {
    print_header "Uninstalling Mobile Coding Setup"

    local os=$(detect_os)

    # Remove Mosh
    print_step "Removing Mosh..."
    if command_exists mosh; then
        case "$os" in
            macos)
                brew uninstall mosh 2>/dev/null || true
                ;;
            linux)
                if command_exists apt; then
                    sudo apt remove -y mosh 2>/dev/null || true
                elif command_exists dnf; then
                    sudo dnf remove -y mosh 2>/dev/null || true
                elif command_exists pacman; then
                    sudo pacman -R --noconfirm mosh 2>/dev/null || true
                fi
                ;;
        esac
        print_success "Mosh removed"
    else
        print_warning "Mosh not installed, skipping"
    fi

    # Remove Tailscale
    print_step "Removing Tailscale..."
    if command_exists tailscale; then
        case "$os" in
            macos)
                brew uninstall --cask tailscale 2>/dev/null || true
                ;;
            linux)
                if command_exists apt; then
                    sudo apt remove -y tailscale 2>/dev/null || true
                elif command_exists dnf; then
                    sudo dnf remove -y tailscale 2>/dev/null || true
                fi
                ;;
        esac
        print_success "Tailscale removed"
    else
        print_warning "Tailscale not installed, skipping"
    fi

    # Re-enable sleep
    print_step "Re-enabling system sleep..."
    case "$os" in
        macos)
            sudo pmset -a sleep 10 disksleep 10 2>/dev/null || true
            print_success "Sleep re-enabled (10 minutes)"
            ;;
        linux)
            sudo systemctl unmask sleep.target suspend.target hibernate.target 2>/dev/null || true
            print_success "Sleep targets unmasked"
            ;;
    esac

    # Restore SSH password auth (optional)
    print_step "SSH configuration..."
    print_warning "SSH key-only auth was not reverted. Manually edit /etc/ssh/sshd_config if needed."

    # Remove mobile tmux script binding
    print_step "Cleaning up tmux configuration..."
    if [[ -f "$DOTFILES_ROOT/scripts/tmux/tmux-mobile-session.sh" ]]; then
        rm -f "$DOTFILES_ROOT/scripts/tmux/tmux-mobile-session.sh"
        print_success "Mobile tmux script removed"
    fi

    # Clear state
    rm -f "$STATE_DIR/${MOBILE_STATE_PREFIX}"*.complete 2>/dev/null || true

    print_header "Uninstall Complete"
    echo "Remote access tools have been removed."
    echo "You may need to restart for all changes to take effect."
}

# ============================================================================
# Phase 1: Install Mosh
# ============================================================================

install_mosh() {
    print_header "Phase 1: Installing Mosh"

    if is_step_complete "${MOBILE_STATE_PREFIX}-mosh"; then
        print_success "Mosh already installed, skipping"
        return 0
    fi

    local os=$(detect_os)

    if command_exists mosh; then
        print_success "Mosh already installed: $(mosh --version 2>&1 | head -1)"
    else
        print_step "Installing Mosh..."
        case "$os" in
            macos)
                brew install mosh
                ;;
            linux)
                if command_exists apt; then
                    sudo apt update && sudo apt install -y mosh
                elif command_exists dnf; then
                    sudo dnf install -y mosh
                elif command_exists pacman; then
                    sudo pacman -S --noconfirm mosh
                else
                    print_error "Unsupported package manager. Install mosh manually."
                    return 1
                fi
                ;;
        esac
        print_success "Mosh installed"
    fi

    mark_step_complete "${MOBILE_STATE_PREFIX}-mosh"
}

# ============================================================================
# Fix Mosh PATH for non-interactive shells
# ============================================================================

fix_mosh_path() {
    print_step "Configuring PATH for Mosh (non-interactive shells)..."

    local os=$(detect_os)
    local homebrew_path=""

    case "$os" in
        macos)
            # Apple Silicon vs Intel
            if [[ -d "/opt/homebrew/bin" ]]; then
                homebrew_path="/opt/homebrew/bin"
            elif [[ -d "/usr/local/bin" ]]; then
                homebrew_path="/usr/local/bin"
            fi
            ;;
        linux)
            # Linux typically uses /usr/bin for mosh
            homebrew_path="/usr/bin"
            ;;
    esac

    if [[ -z "$homebrew_path" ]]; then
        print_warning "Could not determine Homebrew path, skipping .zshenv update"
        return 0
    fi

    # Add to .zshenv (loads for ALL shell types, including non-interactive)
    if [[ -f "$HOME/.zshenv" ]] && grep -q "$homebrew_path" "$HOME/.zshenv" 2>/dev/null; then
        print_success "PATH already configured in ~/.zshenv"
    else
        echo "" >> "$HOME/.zshenv"
        echo "# Added by setup-mobile-coding.sh for Mosh support" >> "$HOME/.zshenv"
        echo "export PATH=\"$homebrew_path:\$PATH\"" >> "$HOME/.zshenv"
        print_success "Added $homebrew_path to PATH in ~/.zshenv"
    fi
}

# ============================================================================
# Phase 2: Install Tailscale
# ============================================================================

install_tailscale() {
    print_header "Phase 2: Installing Tailscale"

    if is_step_complete "${MOBILE_STATE_PREFIX}-tailscale"; then
        print_success "Tailscale already configured, skipping"
        return 0
    fi

    local os=$(detect_os)

    if command_exists tailscale; then
        print_success "Tailscale already installed"
    else
        print_step "Installing Tailscale..."
        case "$os" in
            macos)
                brew install --cask tailscale
                ;;
            linux)
                curl -fsSL https://tailscale.com/install.sh | sh
                ;;
        esac
        print_success "Tailscale installed"
    fi

    # Prompt to authenticate
    echo ""
    print_warning "ACTION REQUIRED: Open Tailscale and sign in"
    echo "  - macOS: Open Tailscale from Applications"
    echo "  - Linux: Run 'sudo tailscale up'"
    echo ""
    echo "Sign in with the SAME account you'll use on your phone."
    echo ""
    read -p "Press Enter when Tailscale is connected..."

    # Verify connection and get MagicDNS hostname
    if tailscale status &>/dev/null; then
        local dns_name=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | sed 's/"DNSName":"//;s/"//' | sed 's/\.$//' || "")
        local hostname=$(tailscale status --json 2>/dev/null | grep -o '"Self":{[^}]*"HostName":"[^"]*"' | sed 's/.*"HostName":"\([^"]*\)".*/\1/' || hostname)
        print_success "Tailscale connected!"
        echo "  Hostname: $hostname"
        if [[ -n "$dns_name" ]]; then
            echo "  MagicDNS: $dns_name"
        fi
    else
        print_warning "Could not verify Tailscale connection. Continue anyway."
    fi

    # MagicDNS guidance
    echo ""
    print_step "IMPORTANT: Enable MagicDNS in Tailscale Admin"
    echo ""
    echo "  1. Go to: https://login.tailscale.com/admin/dns"
    echo "  2. Enable 'MagicDNS' if not already enabled"
    echo "  3. Your devices will be accessible via: machine-name.tailnet-name.ts.net"
    echo ""
    echo "  This allows you to connect using a friendly hostname instead of IP addresses."
    echo ""
    read -p "Press Enter to continue..."

    mark_step_complete "${MOBILE_STATE_PREFIX}-tailscale"
}

# ============================================================================
# Phase 3: Configure SSH
# ============================================================================

configure_ssh() {
    print_header "Phase 3: Configuring SSH"

    if is_step_complete "${MOBILE_STATE_PREFIX}-ssh"; then
        print_success "SSH already configured, skipping"
        return 0
    fi

    local os=$(detect_os)

    # Enable SSH server
    print_step "Enabling SSH server..."
    case "$os" in
        macos)
            if ! sudo systemsetup -getremotelogin | grep -q "On"; then
                sudo systemsetup -setremotelogin on
                print_success "Remote Login enabled"
            else
                print_success "Remote Login already enabled"
            fi
            ;;
        linux)
            if ! systemctl is-active --quiet sshd; then
                sudo systemctl enable --now sshd
                print_success "SSH daemon enabled and started"
            else
                print_success "SSH daemon already running"
            fi
            ;;
    esac

    # Ensure .ssh directory exists with correct permissions
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"

    # Check for SSH key and set up authorization
    print_step "Setting up SSH key authentication..."

    local key_added=false

    # Option 1: Check if 1Password CLI is available and offer to use existing key
    if command_exists op && op account list &>/dev/null; then
        print_step "1Password CLI detected. Checking for existing SSH keys..."
        local ssh_keys=$(op item list --categories "SSH Key" --format=json 2>/dev/null | jq -r '.[].title' 2>/dev/null || echo "")

        if [[ -n "$ssh_keys" ]]; then
            echo ""
            echo "Found SSH keys in 1Password:"
            echo "$ssh_keys" | head -5 | sed 's/^/    - /'
            echo ""
            if confirm "Would you like to use an existing 1Password SSH key for mobile access?"; then
                echo ""
                echo "Enter the name of the SSH key to use (or press Enter to skip):"
                read -r key_name
                if [[ -n "$key_name" ]]; then
                    local pub_key=$(op item get "$key_name" --fields "public_key" 2>/dev/null)
                    if [[ -n "$pub_key" ]]; then
                        if ! grep -q "$pub_key" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
                            echo "$pub_key" >> "$HOME/.ssh/authorized_keys"
                            print_success "Added '$key_name' public key to authorized_keys"
                            key_added=true
                        else
                            print_success "'$key_name' already in authorized_keys"
                            key_added=true
                        fi
                    else
                        print_warning "Could not retrieve public key for '$key_name'"
                    fi
                fi
            fi
        fi
    fi

    # Option 2: Check for local SSH key
    if [[ "$key_added" != "true" ]]; then
        if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
            print_success "Found local SSH key: ~/.ssh/id_ed25519"
            # Add to authorized_keys if not already there
            local local_pub_key=$(cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null)
            if [[ -n "$local_pub_key" ]] && ! grep -q "$local_pub_key" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
                echo "$local_pub_key" >> "$HOME/.ssh/authorized_keys"
                print_success "Added local key to authorized_keys"
                key_added=true
            elif [[ -n "$local_pub_key" ]]; then
                print_success "Local key already in authorized_keys"
                key_added=true
            fi
        elif [[ -f "$HOME/.ssh/id_rsa" ]]; then
            print_success "Found local SSH key: ~/.ssh/id_rsa"
            local local_pub_key=$(cat "$HOME/.ssh/id_rsa.pub" 2>/dev/null)
            if [[ -n "$local_pub_key" ]] && ! grep -q "$local_pub_key" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
                echo "$local_pub_key" >> "$HOME/.ssh/authorized_keys"
                print_success "Added local key to authorized_keys"
                key_added=true
            elif [[ -n "$local_pub_key" ]]; then
                print_success "Local key already in authorized_keys"
                key_added=true
            fi
        fi
    fi

    # Option 3: Generate new SSH key if none exists
    if [[ "$key_added" != "true" ]]; then
        print_warning "No SSH key found."
        echo ""
        if confirm "Generate a new SSH key for mobile access?"; then
            ssh-keygen -t ed25519 -C "mobile-access" -f "$HOME/.ssh/id_ed25519" -N ""
            cat "$HOME/.ssh/id_ed25519.pub" >> "$HOME/.ssh/authorized_keys"
            print_success "Generated new SSH key and added to authorized_keys"
            echo ""
            print_warning "IMPORTANT: Add your new private key to 1Password"
            echo "    Key location: ~/.ssh/id_ed25519"
            echo "    Then import it into Termius from 1Password"
            key_added=true
        else
            print_warning "Skipping SSH key generation. You'll need to set this up manually."
        fi
    fi

    # Configure key-only auth
    print_step "Configuring key-only authentication..."
    local sshd_config="/etc/ssh/sshd_config"

    # Check current settings
    local needs_restart=false
    if sudo grep -q "^PasswordAuthentication yes" "$sshd_config" 2>/dev/null; then
        print_warning "Password authentication is currently enabled"
        echo ""
        echo "For better security, we recommend disabling password authentication."
        echo "This requires your SSH key to be in ~/.ssh/authorized_keys"
        echo ""
        if confirm "Disable password authentication (key-only)?"; then
            sudo sed -i.bak 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$sshd_config"
            sudo sed -i.bak 's/^#PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
            needs_restart=true
            print_success "Password authentication disabled"
        else
            print_warning "Password authentication left enabled (less secure)"
        fi
    else
        print_success "Password authentication already disabled or not configured"
    fi

    # Restart SSH if needed
    if [[ "$needs_restart" == "true" ]]; then
        case "$os" in
            macos)
                sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
                ;;
            linux)
                sudo systemctl restart sshd
                ;;
        esac
        print_success "SSH service restarted"
    fi

    mark_step_complete "${MOBILE_STATE_PREFIX}-ssh"
}

# ============================================================================
# Phase 4: Disable Sleep
# ============================================================================

disable_sleep() {
    print_header "Phase 4: Disabling System Sleep"

    if is_step_complete "${MOBILE_STATE_PREFIX}-sleep"; then
        print_success "Sleep already configured, skipping"
        return 0
    fi

    local os=$(detect_os)

    print_step "Disabling sleep to keep machine accessible 24/7..."
    case "$os" in
        macos)
            # Disable sleep and disk sleep
            sudo pmset -a sleep 0
            sudo pmset -a disksleep 0
            sudo pmset -a displaysleep 15  # Display can still sleep

            # Prevent sleep when on power adapter
            sudo pmset -c sleep 0

            print_success "System sleep disabled (display will sleep after 15 min)"

            # Show current settings
            if [[ "$VERBOSE" == "true" ]]; then
                echo ""
                pmset -g
            fi
            ;;
        linux)
            # Mask sleep-related systemd targets
            sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
            print_success "Sleep/suspend/hibernate targets masked"
            ;;
    esac

    mark_step_complete "${MOBILE_STATE_PREFIX}-sleep"
}

# ============================================================================
# Phase 5: Configure Firewall
# ============================================================================

configure_firewall() {
    print_header "Phase 5: Configuring Firewall for Mosh"

    if is_step_complete "${MOBILE_STATE_PREFIX}-firewall"; then
        print_success "Firewall already configured, skipping"
        return 0
    fi

    local os=$(detect_os)

    print_step "Opening Mosh UDP ports (60000-61000)..."

    case "$os" in
        macos)
            # macOS firewall doesn't block outgoing by default
            # and Tailscale handles the networking
            print_success "macOS: Tailscale handles network routing, no firewall changes needed"
            ;;
        linux)
            if command_exists ufw; then
                sudo ufw allow 60000:61000/udp comment "Mosh"
                print_success "UFW: Mosh ports opened"
            elif command_exists firewall-cmd; then
                sudo firewall-cmd --permanent --add-port=60000-61000/udp
                sudo firewall-cmd --reload
                print_success "firewalld: Mosh ports opened"
            else
                print_warning "No firewall detected. Mosh should work if no firewall is active."
            fi
            ;;
    esac

    mark_step_complete "${MOBILE_STATE_PREFIX}-firewall"
}

# ============================================================================
# Phase 6: Create Mobile tmux Session
# ============================================================================

create_mobile_tmux_session() {
    print_header "Phase 6: Creating Mobile tmux Session"

    if is_step_complete "${MOBILE_STATE_PREFIX}-tmux"; then
        print_success "Mobile tmux session already configured, skipping"
        return 0
    fi

    local tmux_script="$DOTFILES_ROOT/scripts/tmux/tmux-mobile-session.sh"

    print_step "Creating mobile tmux session script..."

    mkdir -p "$(dirname "$tmux_script")"

    cat > "$tmux_script" << 'TMUX_SCRIPT'
#!/usr/bin/env bash

# tmux-mobile-session.sh - Create a mobile-optimized tmux layout
#
# Layout:
# ┌─────────────────────────────────┐
# │          claude (main)          │  ← Primary pane (70% height)
# ├─────────────────────────────────┤
# │    editor    │      shell       │  ← Secondary panes (30% height)
# └─────────────────────────────────┘
#
# Usage:
#   tmux-mobile-session.sh [session-name]
#
# Default session name: mobile

SESSION_NAME="${1:-mobile}"

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session '$SESSION_NAME' already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Create new session with main pane for Claude Code
tmux new-session -d -s "$SESSION_NAME" -n main

# Split horizontally (top 70%, bottom 30%)
tmux split-window -v -p 30

# Split the bottom pane vertically (left: editor, right: shell)
tmux split-window -h -p 50

# Select the top pane (claude)
tmux select-pane -t 0

# Send commands to each pane
# Top pane: Start claude
tmux send-keys -t 0 'claude' Enter

# Bottom-left pane: Ready for nvim
tmux send-keys -t 1 '# Editor pane - run: nvim' Enter

# Bottom-right pane: Shell prompt
tmux send-keys -t 2 '# Shell pane' Enter

# Attach to session
tmux attach-session -t "$SESSION_NAME"
TMUX_SCRIPT

    chmod +x "$tmux_script"
    print_success "Mobile tmux script created: $tmux_script"

    # Add tmux keybinding hint
    echo ""
    print_step "Tip: Add this to your .tmux.conf for quick access:"
    echo "    bind M run-shell '~/dotfiles/scripts/tmux/tmux-mobile-session.sh'"
    echo ""
    echo "Then use: prefix + M to launch mobile session"

    mark_step_complete "${MOBILE_STATE_PREFIX}-tmux"
}

# ============================================================================
# Print Summary
# ============================================================================

print_summary() {
    print_header "Setup Complete!"

    local hostname=$(hostname)
    local tailscale_hostname=""
    if command_exists tailscale && tailscale status &>/dev/null; then
        tailscale_hostname=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | sed 's/"DNSName":"//;s/"//' | sed 's/\.$//' || echo "")
    fi

    cat << EOF

Your machine is now configured for remote mobile development!

VERIFICATION COMMANDS:
    mosh --version          # Verify Mosh installed
    tailscale status        # Verify Tailscale connected
    ssh localhost           # Verify SSH working

YOUR HOSTNAME:
    Local: $hostname
    MagicDNS: ${tailscale_hostname:-"(check Tailscale admin)"}

TAILSCALE ADMIN:
    DNS Settings: https://login.tailscale.com/admin/dns
    Machines:     https://login.tailscale.com/admin/machines

PHONE SETUP (S24 Ultra):
    1. Install Tailscale from Play Store
       - Sign in with the SAME account as this computer

    2. Install Termius from Play Store
       - Create new host:
         - Hostname: ${tailscale_hostname:-$hostname}
         - Username: $USER
         - Enable "Mosh" in connection settings

    3. Import SSH key from 1Password
       - Termius has native 1Password integration
       - This enables passwordless login via Face ID

    4. Connect and run:
       tmux-mobile-session.sh

QUICK START:
    From phone: Connect via Termius → run 'tmux-mobile-session.sh'

EOF
}

# ============================================================================
# Main
# ============================================================================

main() {
    parse_args "$@"

    if [[ "$UNINSTALL" == "true" ]]; then
        preflight_checks
        uninstall_all
        exit 0
    fi

    preflight_checks
    install_mosh
    fix_mosh_path
    install_tailscale
    configure_ssh
    disable_sleep
    configure_firewall
    create_mobile_tmux_session
    print_summary
}

main "$@"
