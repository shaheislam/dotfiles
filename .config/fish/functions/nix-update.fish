function nix-update --description "Update flake.lock in current directory"
    if not test -f flake.nix
        echo "Error: No flake.nix found in current directory"
        return 1
    end

    echo "Updating flake.lock..."
    nix flake update
end
