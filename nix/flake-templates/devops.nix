# DevOps Stack Flake Template
# Includes Terraform, Ansible, Kubernetes, Docker, and Cloud tools

{
  description = "DevOps development environment with infrastructure tools and LSPs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import LSP versions
        lspVersions = import ../global/lsp-versions.nix { inherit pkgs; };

        devPackages = with pkgs; [
          # LSPs for DevOps
          lspVersions.terraform.stable      # Terraform LSP
          lspVersions.ansible.stable         # Ansible LSP
          lspVersions.helm.stable            # Helm LSP
          lspVersions.docker.dockerls        # Docker LSP
          lspVersions.yaml.stable            # YAML LSP (for K8s manifests)
          lspVersions.json.stable            # JSON LSP
          lspVersions.shell.bash             # Bash LSP
          lspVersions.shell.shellcheck       # Shell linter
          lspVersions.shell.shfmt            # Shell formatter
          lspVersions.python.basedpyright    # Python (for Ansible, scripts)
          lspVersions.golang.stable          # Go (for K8s operators, tools)

          # Infrastructure as Code
          terraform
          terragrunt
          terraform-docs
          tflint
          tfsec
          checkov
          infracost

          # Configuration Management
          ansible
          ansible-lint

          # Kubernetes Tools
          kubectl
          kustomize
          helm
          helmfile
          k9s
          kubectx
          stern
          kubernetes-helm

          # Container Tools
          docker
          docker-compose
          dive
          hadolint
          skopeo
          cosign
          trivy

          # Cloud CLIs
          awscli2
          azure-cli
          google-cloud-sdk
          (google-cloud-sdk.withExtraComponents [
            google-cloud-sdk.components.gke-gcloud-auth-plugin
          ])

          # CI/CD Tools
          gh
          act

          # Monitoring & Debugging
          htop
          btop
          jq
          yq-go
          grpcurl
          httpie

          # Security Tools
          vault
          sops
          age
          gnupg
        ];

        shellHook = ''
          echo "🚀 DevOps Nix Environment Activated!"
          echo ""
          echo "📦 Infrastructure Tools:"
          echo "  ✓ Terraform $(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo 'installed')"
          echo "  ✓ Ansible $(ansible --version | head -1 | cut -d' ' -f2 2>/dev/null || echo 'installed')"
          echo "  ✓ Kubectl $(kubectl version --client --short 2>/dev/null | cut -d: -f2 || echo 'installed')"
          echo "  ✓ Helm $(helm version --short 2>/dev/null || echo 'installed')"
          echo ""
          echo "🔧 Available LSPs:"
          which terraform-ls &>/dev/null && echo "  ✓ terraform-ls"
          which ansible-language-server &>/dev/null && echo "  ✓ ansible-language-server"
          which helm_ls &>/dev/null && echo "  ✓ helm_ls"
          which docker-langserver &>/dev/null && echo "  ✓ docker-langserver"
          which yaml-language-server &>/dev/null && echo "  ✓ yaml-language-server"
          which gopls &>/dev/null && echo "  ✓ gopls"
          which basedpyright &>/dev/null && echo "  ✓ basedpyright"
          echo ""

          # Set up kubectl autocompletion
          source <(kubectl completion bash 2>/dev/null || true)

          # Set up helm autocompletion
          source <(helm completion bash 2>/dev/null || true)

          # AWS CLI configuration reminder
          if [ -z "$AWS_PROFILE" ]; then
            echo "💡 Tip: Set AWS_PROFILE environment variable for AWS CLI"
          else
            echo "☁️  AWS Profile: $AWS_PROFILE"
          fi

          # Kubernetes context check
          KUBE_CTX=$(kubectl config current-context 2>/dev/null || echo "none")
          echo "☸️  Kubernetes Context: $KUBE_CTX"
          echo ""
          echo "Ready for infrastructure development! 🏗️"
        '';

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = devPackages;
          inherit shellHook;

          # Environment variables
          ANSIBLE_HOST_KEY_CHECKING = "False";
          TERRAFORM_CLI_ARGS_plan = "-parallelism=10";
          TERRAFORM_CLI_ARGS_apply = "-parallelism=10";
        };

        # Minimal DevOps shell (just LSPs and core tools)
        devShells.minimal = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.terraform.stable
            lspVersions.yaml.stable
            lspVersions.shell.bash
            terraform
            kubectl
            helm
          ];
          shellHook = ''
            echo "Minimal DevOps environment activated"
          '';
        };

        # Cloud-specific shells
        devShells.aws = pkgs.mkShell {
          buildInputs = devPackages ++ (with pkgs; [
            amazon-ecr-credential-helper
            awslogs
            aws-sam-cli
          ]);
          inherit shellHook;
        };

        devShells.azure = pkgs.mkShell {
          buildInputs = devPackages ++ (with pkgs; [
            azure-cli
            azure-storage-azcopy
          ]);
          inherit shellHook;
        };

        devShells.gcp = pkgs.mkShell {
          buildInputs = devPackages ++ (with pkgs; [
            google-cloud-sdk
          ]);
          inherit shellHook;
        };
      });
}