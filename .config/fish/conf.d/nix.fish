# Nix Package Manager Integration for Fish Shell
# Functions moved to ~/.config/fish/functions/ for lazy loading (saves ~15KB parse time at startup)

# Check if Nix is installed
if test -e /nix

    # Source Nix daemon for multi-user installation (macOS)
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
        source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
        # Alternative location for some installations
    else if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix.fish'
        source '/nix/var/nix/profiles/default/etc/profile.d/nix.fish'
        # Single-user installation fallback
    else if test -e "$HOME/.nix-profile/etc/profile.d/nix.fish"
        source "$HOME/.nix-profile/etc/profile.d/nix.fish"
    end

    # Add Nix profile bin to PATH if not already there
    if test -d "$HOME/.nix-profile/bin"
        if not contains "$HOME/.nix-profile/bin" $PATH
            set -gx PATH "$HOME/.nix-profile/bin" $PATH
        end
    end

    # Add Home Manager profile bin to PATH if it exists
    if test -d "$HOME/.local/state/nix/profiles/home-manager/home-path/bin"
        if not contains "$HOME/.local/state/nix/profiles/home-manager/home-path/bin" $PATH
            set -gx PATH "$HOME/.local/state/nix/profiles/home-manager/home-path/bin" $PATH
        end
    end

    # Set NIX_PATH if not already set
    if not set -q NIX_PATH
        set -gx NIX_PATH nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs:/nix/var/nix/profiles/per-user/root/channels
    end

    # Abbreviations for common Nix commands
    abbr --add nd "nix develop"
    abbr --add ndu "nix flake update"
    abbr --add nsh "nix shell"
    abbr --add nsn "nix shell nixpkgs#"
    abbr --add nsr "nix search nixpkgs"
    abbr --add nfu "nix flake update"
    abbr --add ngc "nix-collect-garbage -d"

    # Set environment indicator for prompt (if using custom prompt)
    if set -q IN_NIX_SHELL
        set -gx NIX_SHELL_INDICATOR "❄️"
    end

    # Abbreviations for Home Manager
    abbr --add hms hm-switch
    abbr --add hmu hm-update
    abbr --add hmp hm-packages
    abbr --add hmg hm-generations

end
# Note: nix-install function available in functions/ dir even when Nix not installed
