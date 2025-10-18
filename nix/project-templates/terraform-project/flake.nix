# Terraform/Infrastructure Project - Override Global LSPs
# Example: Using newer terraform-ls for latest provider support
{
  description = "Terraform project with specific LSP versions - demonstrating hybrid approach";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # Using unstable for latest terraform tools
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Terraform tools
            terraform  # Or terraform_1_6, terraform_1_5 for specific versions
            terragrunt

            # OVERRIDE EXAMPLE: Latest terraform-ls from unstable
            # This overrides the global stable terraform-ls
            terraform-ls  # Latest LSP with newest provider support

            # Keep using global linter
            tflint

            # Project-specific tools (not in global)
            terraform-docs
            tfsec
            checkov
            infracost

            # Cloud CLIs
            awscli2
            azure-cli
            google-cloud-sdk

            # Additional tools
            jq
            yq-go
            sops
            pre-commit

            # LSPs
            yaml-language-server
            nodePackages.vscode-langservers-extracted  # JSON LSP
          ];

          shellHook = ''
            echo "🏗️ Terraform Project with LSP Overrides (Hybrid Approach)"
            echo "======================================================="
            terraform version | head -n 1
            echo ""
            echo "🔄 LSP Overrides:"
            echo "  • terraform-ls (latest from unstable, overriding global)"
            echo "  • tflint (using global version)"
            echo ""
            echo "📦 Project-specific tools:"
            echo "  • tfsec, checkov (security scanning)"
            echo "  • terraform-docs (documentation)"
            echo "  • infracost (cost estimation)"
            echo ""

            # Auto-format on save setup
            if [ ! -f .terraform-version ]; then
              echo "💡 Tip: Create .terraform-version to pin Terraform version"
            fi

            # Pre-commit setup
            if [ -f .pre-commit-config.yaml ] && command -v pre-commit &>/dev/null; then
              pre-commit install 2>/dev/null || true
            fi
          '';

          # Terraform-specific environment variables
          TF_PLUGIN_CACHE_DIR = "$HOME/.terraform.d/plugin-cache";
          TF_CLI_ARGS_plan = "-parallelism=10";
          TF_CLI_ARGS_apply = "-parallelism=10";
        };
      });
}