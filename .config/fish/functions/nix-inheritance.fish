function nix-inheritance --description "Show Nix environment inheritance chain"
    echo "Nix Environment Inheritance"
    echo "=============================="

    # Check Home Manager
    if test -e "$HOME/.local/state/nix/profiles/home-manager"
        echo "✓ Home Manager: Active"
        echo "   Profile: $HOME/.local/state/nix/profiles/home-manager"
    else if test -d "$HOME/.nix-profile"
        echo "✓ Nix Profile: Active (Home Manager may be integrated)"
        echo "   Profile: $HOME/.nix-profile"
    else
        echo "✗ Home Manager: Not active"
    end

    # Check global environment
    if test -f "$HOME/dotfiles/nix/global/flake.nix"
        echo "✓ Global Dev Profile: Available"
    end

    # Check for work base
    if test -n "$WORK_NIX_BASE"
        echo "✓ Work Base: $WORK_ROOT"
    end

    # Check current directory
    if test -f flake.nix
        echo "✓ Local flake: $PWD/flake.nix"
        if test -f flake.lock
            echo "   Locked: Yes"
        else
            echo "   Locked: No (run 'nix flake update')"
        end
    end

    # Check if in Nix shell
    if set -q IN_NIX_SHELL
        echo ""
        echo "Active Nix Shell: $name"
    end

    # Show active LSPs
    echo ""
    echo "Available LSPs:"
    nix-lsps
end
