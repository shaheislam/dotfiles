#!/usr/bin/env bash
#
# macOS System Preferences - Developer Optimizations
# Run: bash scripts/macos-defaults.sh

set -euo pipefail

echo "🍎 Configuring macOS developer defaults..."

# Close System Preferences to prevent conflicts
osascript -e 'quit app "System Preferences"'

# =============================================================================
# Keyboard & Input
# =============================================================================

# Disable auto-correct (annoying for coding)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable smart quotes and dashes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Enable full keyboard access for all controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Set US keyboard layout (ABC) as default input source
defaults write com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID -string "com.apple.keylayout.ABC"
defaults write -g AppleCurrentKeyboardLayoutInputSourceID -string "com.apple.keylayout.ABC"

# Fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Disable press-and-hold for accents (enable key repeat)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# =============================================================================
# Finder
# =============================================================================

# Show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Default to list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# =============================================================================
# Dock & Mission Control
# =============================================================================

# Auto-hide Dock
defaults write com.apple.dock autohide -bool true

# Remove auto-hide delay
defaults write com.apple.dock autohide-delay -float 0

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Don't automatically rearrange Spaces
defaults write com.apple.dock mru-spaces -bool false

# =============================================================================
# Terminal
# =============================================================================

# Use UTF-8 only
defaults write com.apple.terminal StringEncodings -array 4

# Enable Secure Keyboard Entry
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# =============================================================================
# Screenshots
# =============================================================================

# Save screenshots to Downloads
defaults write com.apple.screencapture location -string "${HOME}/Downloads"

# Save screenshots in PNG format
defaults write com.apple.screencapture type -string "png"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# =============================================================================
# Performance
# =============================================================================

# Disable animations
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Disable smooth scrolling
defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

# =============================================================================
# Network & DNS
# =============================================================================

# Configure DNS to use Cloudflare (bypasses UK ISP DNS blocking)
# Note: ISPs like Sky/Virgin use DNS-level blocking for court-ordered sites
# Cloudflare DNS (1.1.1.1) doesn't implement these blocks and is faster
echo "🌐 Configuring DNS to Cloudflare..."

# Get all hardware network services (Wi-Fi, Ethernet, etc.)
while IFS= read -r service; do
    # Skip empty lines and disabled services (marked with *)
    [[ -z "$service" || "$service" == *"*"* ]] && continue

    # Skip virtual interfaces
    [[ "$service" == "Tailscale" || "$service" == "Thunderbolt Bridge" ]] && continue

    # Set DNS for this service
    if networksetup -setdnsservers "$service" 1.1.1.1 1.0.0.1 2>/dev/null; then
        echo "  ✓ DNS configured for: $service"
    fi
done < <(networksetup -listallnetworkservices | tail -n +2)

# Flush DNS cache to apply changes immediately
if [[ "${NO_SUDO:-false}" == "true" ]]; then
    echo "  ⚠ DNS cache flush skipped (--no-sudo)"
else
    sudo dscacheutil -flushcache 2>/dev/null || true
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    echo "  ✓ DNS cache flushed"
fi

# =============================================================================
# Apply Changes
# =============================================================================

echo "✅ macOS defaults configured!"
echo "⚠️  Some changes require logout/restart to take effect"

# Restart affected apps
for app in "Finder" "Dock" "SystemUIServer"; do
    killall "${app}" &>/dev/null || true
done

echo "🔄 Finder, Dock, and SystemUIServer restarted"
