function nix-search --description "Search for Nix packages"
    if test (count $argv) -eq 0
        echo "Usage: nix-search <package-name>"
        return 1
    end

    nix search nixpkgs $argv[1]
end
