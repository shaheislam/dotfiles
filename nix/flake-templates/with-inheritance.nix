# Template for Projects that Inherit from Global Environment
# This template shows how to extend or override the global development environment

{
  description = "Project development environment with global inheritance";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";

    # Inherit from global environment
    global-env.url = "path:/Users/shaheislam/dotfiles/nix/global";

    # Or inherit from parent directory (for nested projects)
    # parent.url = "path:..";
  };

  outputs = { self, nixpkgs, flake-utils, global-env, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import LSP versions if needed
        lspVersions = import ../../lsp-versions.nix { inherit pkgs; };
      in {
        devShells = {
          # Default: Extend the global environment
          default = pkgs.mkShell {
            # Inherit all packages from global
            inputsFrom = [ global-env.devShells.${system}.default ];

            # Add project-specific packages
            buildInputs = with pkgs; [
              # Add your project-specific tools here
              # nodejs_20
              # python311
              # gopls
            ];

            shellHook = ''
              # Run global hook first
              ${global-env.lib.${system}.commonShellHook or ""}

              # Project-specific setup
              echo "📁 Project: $(basename $PWD)"
              echo "   Environment: Extended from global"

              # Your project-specific setup here
            '';

            # Project-specific environment variables
            PROJECT_ENV = "development";
          };

          # Alternative: Replace global with custom environment
          isolated = pkgs.mkShell {
            # Don't inherit, define everything fresh
            buildInputs = with pkgs; [
              # Only these packages, no inheritance
              git
              nodejs
              typescript
            ];

            shellHook = ''
              echo "📁 Isolated environment (no global packages)"
            '';
          };

          # Alternative: Selective inheritance
          selective = pkgs.mkShell {
            # Manually pick what to inherit
            buildInputs =
              # Take only some packages from global
              (with global-env.lib.${system}.packages; [
                golang.stable
                terraform.stable
              ]) ++
              # Add project-specific packages
              (with pkgs; [
                kubernetes-helm
                k9s
              ]);

            shellHook = ''
              echo "📁 Selective environment"
            '';
          };

          # Alternative: Override specific packages
          override = pkgs.mkShell rec {
            # Get global packages but filter out ones we want to override
            globalPackages = builtins.filter
              (p: !(builtins.elem (pkgs.lib.getName p) ["python" "gopls"]))
              global-env.devShells.${system}.default.buildInputs;

            buildInputs = globalPackages ++ (with pkgs; [
              # Our versions of filtered packages
              python39  # Instead of global Python
              gopls     # Specific version
            ]);

            shellHook = ''
              echo "📁 Override environment"
              echo "   Using custom Python and gopls versions"
            '';
          };
        };
      });
}