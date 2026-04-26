# Nix Package Manager Integration for Fish Shell
# Functions moved to ~/.config/fish/functions/ for lazy loading (saves ~15KB parse time at startup)

# Check if Nix is installed
if test -e /nix

    # Skip the daemon source if PATH already contains ~/.nix-profile/bin
    # (means a parent shell or fish_user_paths already exported the env vars
    # nix-daemon.fish would set — re-sourcing wastes ~10ms of stat() calls).
    if not contains "$HOME/.nix-profile/bin" $PATH
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
    end

    # Append Nix profile bin to PATH so Homebrew's newer git/etc. win.
    # (Prepending caused Starship to call /nix/store/...git-2.44.2 and time out.)
    if test -d "$HOME/.nix-profile/bin"
        if not contains "$HOME/.nix-profile/bin" $PATH
            set -gx PATH $PATH "$HOME/.nix-profile/bin"
        end
    end

    # Append Home Manager profile bin (same reasoning as above)
    if test -d "$HOME/.local/state/nix/profiles/home-manager/home-path/bin"
        if not contains "$HOME/.local/state/nix/profiles/home-manager/home-path/bin" $PATH
            set -gx PATH $PATH "$HOME/.local/state/nix/profiles/home-manager/home-path/bin"
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
