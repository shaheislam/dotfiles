function nix-clean --description "Clean up Nix store (garbage collection)"
    echo "Running Nix garbage collection..."
    nix-collect-garbage -d
    echo "Optimizing Nix store..."
    nix-store --optimise
end
