function nix-shell-with --description "Start nix shell with specified packages"
    if test (count $argv) -eq 0
        echo "Usage: nix-shell-with package1 [package2 ...]"
        echo "Example: nix-shell-with nodejs python3 go"
        return 1
    end

    set -l packages
    for pkg in $argv
        set packages $packages "nixpkgs#$pkg"
    end

    echo "Starting Nix shell with: $argv"
    nix shell $packages
end
