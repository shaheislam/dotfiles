# Global Development Profile
# This provides a base development environment that projects can inherit from
# Projects can either extend this (add more packages) or override it completely

{ pkgs ? import <nixpkgs> {}, pkgs-unstable ? pkgs }:

let
  # Import LSP versions
  lspVersions = import ./lsp-versions.nix {
    inherit pkgs;
    pkgs-unstable = pkgs-unstable;
  };

  # Common development packages used across most projects
  commonDevPackages = with pkgs; [
    # === Version Control ===
    git
    gh
    pre-commit

    # === Build Tools ===
    gnumake
    cmake
    pkg-config

    # === Language Servers ===
    # Go
    lspVersions.golang.gopls
    lspVersions.golang.delve
    lspVersions.golang.golangci-lint
    # lspVersions.golang.gofumpt  # Formatter - enable per project

    # Python
    # Using basedpyright from unstable channel
    lspVersions.python.basedpyright
    lspVersions.python.ruff-lsp
    lspVersions.python.debugpy
    # lspVersions.python.black  # Formatter - enable per project
    # lspVersions.python.isort  # Formatter - enable per project

    # Rust
    lspVersions.rust.stable
    # lspVersions.rust.rustfmt  # Formatter - enable per project

    # TypeScript/JavaScript
    lspVersions.typescript.stable
    lspVersions.typescript.vtsls
    lspVersions.typescript.eslint-lsp
    # Debug adapters - not available as individual packages
    # lspVersions.typescript.js-debug-adapter
    # lspVersions.typescript.chrome-debug-adapter
    # lspVersions.typescript.firefox-debug-adapter
    # lspVersions.typescript.prettier  # Formatter - enable per project

    # Terraform
    lspVersions.terraform.terraform-ls
    lspVersions.terraform.tflint

    # Shell
    lspVersions.shell.bash-language-server
    lspVersions.shell.shellcheck
    # lspVersions.shell.shfmt  # Formatter - enable per project

    # Docker
    lspVersions.docker.dockerfile-language-server
    lspVersions.docker.docker-compose-language-service
    lspVersions.docker.hadolint

    # YAML
    lspVersions.yaml.stable
    lspVersions.yaml.yamllint

    # JSON
    lspVersions.json.json-lsp
    lspVersions.json.jsonlint

    # GraphQL
    lspVersions.graphql.stable

    # Protocol Buffers
    lspVersions.protobuf.bufls

    # Ansible
    lspVersions.ansible.stable

    # Helm
    lspVersions.helm.stable

    # Lua
    lspVersions.lua.lua-language-server
    # lspVersions.lua.stylua  # Formatter - enable per project

    # Markdown
    lspVersions.markdown.marksman
    lspVersions.markdown.markdownlint

    # SQL
    lspVersions.sql.sqlls
    # lspVersions.sql.sql-formatter  # Formatter - enable per project
    # lspVersions.sql.sqlfluff  # Formatter - enable per project

    # Nix
    lspVersions.nix.nil

    # Java
    lspVersions.java.jdtls

    # C/C++
    lspVersions.cpp.clangd

    # TOML
    lspVersions.toml.taplo  # TOML LSP and formatter

    # === Development Tools ===
    entr        # File watcher
    just        # Command runner
    direnv      # Environment management

    # === Debugging & Performance ===
    # strace  # Linux only
    # ltrace  # Linux only
    time
    hyperfine

    # === Documentation ===
    pandoc

    # === Container Tools ===
    docker-client
    docker-compose

    # === Cloud CLIs (commonly needed) ===
    awscli2
    kubectl
    kubernetes-helm

    # === Database Clients ===
    postgresql
    redis
    sqlite
  ];

  # Shell hook that runs for all environments
  commonShellHook = ''
    echo "🚀 Global Development Environment Loaded"
    echo "   Base: ~/dotfiles/nix/global"

    # Set common environment variables
    export GLOBAL_NIX_PROFILE="true"

    # Ensure direnv is hooked (if not already)
    if command -v direnv &>/dev/null; then
      eval "$(direnv hook $SHELL)"
    fi
  '';

in {
  # Default development shell that projects can inherit
  devShell = pkgs.mkShell {
    buildInputs = commonDevPackages;
    shellHook = commonShellHook;

    # Common environment variables
    EDITOR = "nvim";
    PAGER = "less";
    DEVELOPMENT_ENV = "nix-global";
  };

  # Minimal shell (just LSPs and essential tools)
  minimalShell = pkgs.mkShell {
    buildInputs = with pkgs; [
      git
      lspVersions.shell.bash
      lspVersions.nix.nil
      direnv
    ];
    shellHook = ''
      echo "Minimal global environment loaded"
    '';
  };

  # Export packages for reuse
  inherit commonDevPackages commonShellHook;

  # Export specific package sets that projects might want
  packages = {
    inherit (lspVersions)
      golang
      python
      rust
      terraform
      typescript
      docker
      ansible;

    cloudTools = with pkgs; [
      awscli2
      azure-cli
      google-cloud-sdk
      kubectl
      k9s
      kubernetes-helm
      kustomize
    ];

    databases = with pkgs; [
      postgresql
      mysql80
      redis
      mongodb-tools
      sqlite
    ];

    monitoring = with pkgs; [
      prometheus
      grafana
      htop
      bottom
      ctop
    ];
  };
}