# Nix Package Manager Integration for Fish Shell
# Functions moved to ~/.config/fish/functions/ for lazy loading (saves ~15KB parse time at startup)

# Check if Nix is installed
if test -e /nix

    # Set the small Nix daemon environment subset directly. Sourcing
    # nix-daemon.fish is slower and prepends Nix bins ahead of Homebrew.
    set -l _nix_link "$HOME/.nix-profile"
    if set -q XDG_STATE_HOME; and test -e "$XDG_STATE_HOME/nix/profile"
        set _nix_link "$XDG_STATE_HOME/nix/profile"
    else if test -e "$HOME/.local/state/nix/profile"
        set _nix_link "$HOME/.local/state/nix/profile"
    end

    if not set -q NIX_PROFILES
        set -gx NIX_PROFILES "/nix/var/nix/profiles/default $_nix_link"
    end

    if not set -q NIX_SSL_CERT_FILE
        for _nix_cert in \
            /etc/ssl/certs/ca-certificates.crt \
            /etc/ssl/ca-bundle.pem \
            /etc/ssl/certs/ca-bundle.crt \
            /etc/pki/tls/certs/ca-bundle.crt \
            "$_nix_link/etc/ssl/certs/ca-bundle.crt" \
            "$_nix_link/etc/ca-bundle.crt" \
            /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
            /nix/var/nix/profiles/default/etc/ca-bundle.crt
            if test -e "$_nix_cert"
                set -gx NIX_SSL_CERT_FILE "$_nix_cert"
                break
            end
        end
    end

    set -l _nix_xdg_entries "$_nix_link/share" /nix/var/nix/profiles/default/share
    if set -q XDG_DATA_DIRS; and test -n "$XDG_DATA_DIRS"
        set -l _xdg_data_dirs (string split : -- "$XDG_DATA_DIRS")
        for _nix_xdg_entry in $_nix_xdg_entries
            if test -d "$_nix_xdg_entry"; and not contains -- "$_nix_xdg_entry" $_xdg_data_dirs
                set -a _xdg_data_dirs "$_nix_xdg_entry"
            end
        end
        set -gx XDG_DATA_DIRS (string join : -- $_xdg_data_dirs)
    else
        set -l _xdg_data_dirs /usr/local/share /usr/share
        for _nix_xdg_entry in $_nix_xdg_entries
            if test -d "$_nix_xdg_entry"
                set -a _xdg_data_dirs "$_nix_xdg_entry"
            end
        end
        set -gx XDG_DATA_DIRS (string join : -- $_xdg_data_dirs)
    end

    # Append Nix profile bin to PATH so Homebrew's newer git/etc. win.
    # (Prepending caused Starship to call /nix/store/...git-2.44.2 and time out.)
    if test -d "$HOME/.nix-profile/bin"
        if not contains "$HOME/.nix-profile/bin" $PATH
            set -gx PATH $PATH "$HOME/.nix-profile/bin"
        end
    end

    # Multi-user Nix keeps the nix binary in the default profile, not the user
    # profile. Append it so `nix` works without taking precedence over Homebrew.
    if test -d /nix/var/nix/profiles/default/bin
        if not contains /nix/var/nix/profiles/default/bin $PATH
            set -gx PATH $PATH /nix/var/nix/profiles/default/bin
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
