function nix-status --description "Show Nix environment status"
    echo "Nix Environment Status"
    echo "========================"
    echo ""

    # Check Nix version
    if command -v nix >/dev/null 2>&1
        set -l nix_version (nix --version | string split ' ')[3]
        echo "Nix Version: $nix_version"
    else
        echo "Nix: Not installed"
        return 1
    end

    # Check if in Nix shell
    if set -q IN_NIX_SHELL
        echo "Nix Shell: Active"
        if set -q name
            echo "Shell Name: $name"
        end
    else
        echo "Nix Shell: Inactive"
    end

    # Check for flake.nix
    if test -f flake.nix
        echo "Flake: Found"
        if test -f flake.lock
            echo "Flake Lock: Found"
            set -l lock_date (date -r flake.lock "+%Y-%m-%d %H:%M" 2>/dev/null || stat -f "%Sm" -t "%Y-%m-%d %H:%M" flake.lock 2>/dev/null || echo "unknown")
            echo "Last Updated: $lock_date"
        else
            echo "Flake Lock: Not found (run 'nix flake update')"
        end
    else
        echo "Flake: Not found in current directory"
    end

    # Check direnv status
    if command -v direnv >/dev/null 2>&1
        if test -f .envrc
            echo "Direnv: Configured"
            if direnv status | grep -q "Found RC allowed"
                echo "Direnv Status: Allowed"
            else
                echo "Direnv Status: Not allowed (run 'direnv allow')"
            end
        else
            echo "Direnv: No .envrc file"
        end
    else
        echo "Direnv: Not installed"
    end

    echo ""
    echo "Available LSPs:"
    nix-lsps
end
