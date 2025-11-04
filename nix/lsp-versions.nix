# LSP Version Registry for Nix-based LSP Management
# This file defines centralized LSP versions for consistent development environments

{ pkgs, pkgs-unstable ? pkgs }:
{
  # Go Language Server
  golang = {
    legacy = pkgs.gopls.overrideAttrs (oldAttrs: rec {
      version = "0.11.0";
      src = pkgs.fetchFromGitHub {
        owner = "golang";
        repo = "tools";
        rev = "gopls/v${version}";
        sha256 = "sha256-X7gatcSD3Bgf/FNPKP44mJOXMpe3x7vfOUEm0BG6xJQ=";
      };
      vendorHash = "sha256-OnCGDMnqnn8JgMnTKPwP5vd8+CFh8OmG8vj6VYNjt6w=";
    });
    stable = pkgs.gopls; # Current stable from nixpkgs
    latest = pkgs.gopls; # Can override with unstable or master
    gopls = pkgs.gopls;
    # Linter
    golangci-lint = pkgs.golangci-lint;
    # Formatter - enable per project
    # gofumpt = pkgs.gofumpt;
    # Debug adapter
    delve = pkgs.delve;
  };

  # Terraform Language Server
  terraform = {
    legacy = pkgs.terraform-ls.overrideAttrs (oldAttrs: rec {
      version = "0.30.0";
      src = pkgs.fetchFromGitHub {
        owner = "hashicorp";
        repo = "terraform-ls";
        rev = "v${version}";
        sha256 = "sha256-PLACEHOLDER"; # Would need actual hash
      };
    });
    stable = pkgs.terraform-ls;
    latest = pkgs.terraform-ls;
    terraform-ls = pkgs.terraform-ls;
    # Linter
    tflint = pkgs.tflint;
  };

  # Python Language Servers
  python = {
    # basedpyright from unstable channel (not available in 24.05)
    basedpyright = pkgs-unstable.basedpyright;
    # Keep pyright from stable as fallback
    pyright = pkgs.nodePackages.pyright;
    pylsp = pkgs.python3Packages.python-lsp-server;
    # ruff-lsp is the LSP wrapper for ruff (modern: use `ruff server` when available)
    ruff = pkgs.ruff-lsp;
    ruff-lsp = pkgs.ruff-lsp;
    # Formatters - enable per project
    # black = pkgs.python3Packages.black;
    # isort = pkgs.python3Packages.isort;
    # Debug adapter
    debugpy = pkgs.python3Packages.debugpy;
  };

  # Rust Language Server
  rust = {
    stable = pkgs.rust-analyzer;
    nightly = pkgs.rust-analyzer; # Can override with nightly version
    # Formatter - enable per project
    # rustfmt = pkgs.rustfmt;
  };

  # TypeScript/JavaScript
  typescript = {
    stable = pkgs.nodePackages.typescript-language-server;
    tsserver = pkgs.nodePackages.typescript-language-server;
    vtsls = pkgs.nodePackages.vscode-langservers-extracted; # Vue TypeScript Language Server
    eslint = pkgs.nodePackages.vscode-langservers-extracted;
    eslint-lsp = pkgs.nodePackages.vscode-langservers-extracted;
    # Formatter - enable per project
    # prettier = pkgs.nodePackages.prettier;
    # Debug adapters - these may not be available as individual packages
    # js-debug-adapter = pkgs.nodePackages.vscode-js-debug;
    # chrome-debug-adapter = pkgs.nodePackages.vscode-chrome-debug;
    # firefox-debug-adapter = pkgs.nodePackages.vscode-firefox-debug;
  };

  # YAML Language Server
  yaml = {
    stable = pkgs.yaml-language-server;
    # Linter
    yamllint = pkgs.yamllint;
  };

  # Docker/Container Tools
  docker = {
    dockerls = pkgs.dockerfile-language-server-nodejs;
    dockerfile-language-server = pkgs.dockerfile-language-server-nodejs;
    docker-compose-language-service = pkgs.docker-compose-language-service;
    hadolint = pkgs.hadolint;
  };

  # Ansible
  ansible = {
    stable = pkgs.ansible-language-server;
    ansible-lint = pkgs.ansible-lint;
  };

  # Helm
  helm = {
    stable = pkgs.helm-ls;
  };

  # Lua (for Neovim config)
  lua = {
    stable = pkgs.lua-language-server;
    lua-language-server = pkgs.lua-language-server;
    # Formatter - enable per project
    # stylua = pkgs.stylua;
  };

  # Markdown
  markdown = {
    marksman = pkgs.marksman;
    ltex = pkgs.ltex-ls; # Grammar/spell checking
    # Linter
    markdownlint = pkgs.markdownlint-cli;
  };

  # Shell scripting
  shell = {
    bash = pkgs.nodePackages.bash-language-server;
    bash-language-server = pkgs.nodePackages.bash-language-server;
    shellcheck = pkgs.shellcheck;
    # Formatter - enable per project
    # shfmt = pkgs.shfmt;
  };

  # JSON
  json = {
    stable = pkgs.nodePackages.vscode-langservers-extracted;
    json-lsp = pkgs.nodePackages.vscode-langservers-extracted;
    # Linter
    jsonlint = pkgs.nodePackages.jsonlint;
  };

  # TOML
  toml = {
    taplo = pkgs.taplo;  # TOML LSP and formatter
  };

  # SQL
  sql = {
    sqls = pkgs.sqls;
    sqlls = pkgs.sqls;  # SQL Language Server
    # Formatters - enable per project
    # sql-formatter = pkgs.sqlfluff;
    # sqlfluff = pkgs.sqlfluff;
  };

  # Protocol Buffers
  protobuf = {
    bufls = pkgs.buf-language-server;
  };

  # GraphQL
  graphql = {
    stable = pkgs.nodePackages.graphql-language-service-cli;
  };

  # Nix
  nix = {
    nil = pkgs.nil; # Nix LSP
    nixpkgs-fmt = pkgs.nixpkgs-fmt;
    statix = pkgs.statix; # Nix linter
  };

  # Java/JVM
  java = {
    jdtls = pkgs.jdt-language-server;
  };

  # C/C++
  cpp = {
    clangd = pkgs.clang-tools;
  };

  # PowerShell
  powershell = {
    # powershell-editor-services = pkgs.powershell;  # Not available as separate package in nixpkgs
  };
}