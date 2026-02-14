function nix-install --description "Install Nix package manager"
    echo "Nix is not installed. Would you like to install it?"
    echo ""
    echo "Installation will use the Determinate Systems installer for better macOS support."
    echo "This requires sudo access for the multi-user installation."
    echo ""
    read -P "Install Nix now? (y/n) " -n 1 response
    echo ""

    if test "$response" = y
        echo "Installing Nix..."
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
        echo ""
        echo "✓ Nix installed! Please restart your shell or run:"
        echo "  exec fish"
    else
        echo "Skipping Nix installation."
        echo "You can install it later with: nix-install"
    end
end
