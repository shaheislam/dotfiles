function hm-update --description "Update and switch Home Manager"
    if test -f "$HOME/.config/home-manager/flake.nix"
        echo "Updating Home Manager configuration..."
        cd "$HOME/.config/home-manager" && nix flake update && nix build ".#homeConfigurations.$USER.activationPackage" && ./result/activate && cd -
    else
        echo "Error: Home Manager flake not found"
        return 1
    end
end
