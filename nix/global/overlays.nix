# Global Overlays for Package Customization
# These overlays apply to all Nix usage when imported

{
  # Default overlay with common package overrides
  default = final: prev: {
    # Example: Pin specific tool versions globally
    terraform = prev.terraform.overrideAttrs (old: {
      version = "1.6.0";  # Pin Terraform version
    });

    # Example: Add custom aliases or wrappers
    nvim-configured = prev.writeShellScriptBin "nvim" ''
      export NIX_LSP_ENABLED=true
      ${prev.neovim}/bin/nvim "$@"
    '';

    # Example: Custom package combinations
    devtools-essential = prev.buildEnv {
      name = "devtools-essential";
      paths = with prev; [
        git
        ripgrep
        fd
        bat
        fzf
      ];
    };
  };

  # Overlay for using latest versions from nixpkgs-unstable
  unstable = final: prev:
    let
      unstable = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
      }) {
        config = prev.config;
        system = prev.system;
      };
    in {
      # Use unstable versions of specific packages
      gopls-unstable = unstable.gopls;
      rust-analyzer-unstable = unstable.rust-analyzer;
    };

  # Overlay for custom-built packages
  custom = final: prev: {
    # Example: Build from specific git commits
    terraform-ls-custom = prev.terraform-ls.overrideAttrs (old: {
      src = prev.fetchFromGitHub {
        owner = "hashicorp";
        repo = "terraform-ls";
        rev = "main";  # Or specific commit
        sha256 = prev.lib.fakeSha256;  # Replace with actual hash
      };
    });
  };
}