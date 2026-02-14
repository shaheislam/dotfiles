function hm-switch --description "Switch to Home Manager configuration"
    if test -f "$HOME/.config/home-manager/flake.nix"
        echo "Switching to Home Manager configuration..."
        cd "$HOME/.config/home-manager" && nix build ".#homeConfigurations.$USER.activationPackage" && ./result/activate && cd -
    else
        echo "Error: Home Manager flake not found at ~/.config/home-manager/flake.nix"
        return 1
    end
end
