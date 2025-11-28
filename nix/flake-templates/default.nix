# Default Flake Template for Project-Specific LSP Management
# Copy this to your project root as flake.nix and customize as needed

{
  description = "Development environment with Nix-managed LSPs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";

    # Optional: Use nixpkgs-unstable for bleeding-edge packages
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import LSP versions
        lspVersions = import ../global/lsp-versions.nix { inherit pkgs; };

        # Custom packages or overrides
        customPackages = {
          # Add custom package definitions here
        };

        # Development shell packages
        devPackages = with pkgs; [
          # Version control
          git
          gh

          # Build tools
          gnumake
          cmake

          # LSPs (customize based on project needs)
          lspVersions.lua.stable     # For Neovim configs
          lspVersions.shell.bash      # For shell scripts
          lspVersions.shell.shellcheck
          lspVersions.nix.nil        # For Nix files

          # Utilities
          ripgrep
          fd
          bat
          jq
          yq

          # Project-specific tools
          # Add your project-specific tools here
        ];

        # Shell hook for environment setup
        shellHook = ''
          echo "🚀 Nix development environment activated!"
          echo "📦 Available LSPs:"

          # List available LSPs
          which gopls &>/dev/null && echo "  ✓ gopls ($(gopls version | head -1))"
          which terraform-ls &>/dev/null && echo "  ✓ terraform-ls"
          which rust-analyzer &>/dev/null && echo "  ✓ rust-analyzer"
          which pyright &>/dev/null && echo "  ✓ pyright"
          which typescript-language-server &>/dev/null && echo "  ✓ typescript-language-server"
          which lua-language-server &>/dev/null && echo "  ✓ lua-language-server"
          which nil &>/dev/null && echo "  ✓ nil (Nix LSP)"

          echo ""
          echo "💡 Tip: Your Neovim will automatically detect and use these LSPs"
          echo "🔄 To update: nix flake update"
          echo "🗑️  To clean: nix-collect-garbage -d"
        '';

      in {
        # Default development shell
        devShells.default = pkgs.mkShell {
          buildInputs = devPackages;
          inherit shellHook;

          # Environment variables
          NIX_LSP_ENABLED = "true";
          # Add project-specific environment variables here
        };

        # Additional specialized shells (optional)
        devShells = {
          # Minimal shell with just LSPs
          minimal = pkgs.mkShell {
            buildInputs = with pkgs; [
              lspVersions.shell.bash
              lspVersions.nix.nil
            ];
            shellHook = ''
              echo "Minimal LSP environment activated"
            '';
          };

          # Full development shell with all tools
          full = pkgs.mkShell {
            buildInputs = devPackages ++ (with pkgs; [
              # Additional development tools
              docker
              docker-compose
              kubectl
            ]);
            inherit shellHook;
          };
        };

        # Packages (optional - for building project artifacts)
        packages = {
          # Define buildable packages here
        };

        # Apps (optional - for runnable scripts)
        apps = {
          # Define executable apps here
        };
      });
}