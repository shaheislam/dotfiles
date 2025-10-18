# Backend Development Stack Flake Template
# Includes Go, Rust, Python, and API development tools

{
  description = "Backend development environment with multiple language LSPs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import LSP versions
        lspVersions = import ../../lsp-versions.nix { inherit pkgs; };

        devPackages = with pkgs; [
          # LSPs for Backend Languages
          lspVersions.golang.stable         # Go LSP
          lspVersions.rust.stable            # Rust LSP
          lspVersions.python.basedpyright    # Python LSP (enhanced Pyright)
          lspVersions.python.ruff            # Python linter/formatter
          lspVersions.python.black           # Python formatter
          lspVersions.typescript.stable      # TypeScript (for Node.js backends)
          lspVersions.sql.sqls               # SQL LSP
          lspVersions.protobuf.bufls         # Protocol Buffers
          lspVersions.graphql.stable         # GraphQL
          lspVersions.json.stable            # JSON
          lspVersions.yaml.stable            # YAML
          lspVersions.toml.taplo             # TOML

          # Language Runtimes & Compilers
          go
          rustc
          cargo
          rustfmt
          clippy
          python311
          python311Packages.pip
          python311Packages.setuptools
          nodejs_20
          nodePackages.npm
          nodePackages.yarn
          nodePackages.pnpm

          # Database Tools
          postgresql
          mysql80
          redis
          mongodb-tools
          sqlite
          sqlc
          dbmate

          # API Development Tools
          postman
          insomnia
          grpcurl
          grpcui
          protobuf
          buf
          openapi-generator-cli
          swagger-codegen

          # Testing Tools
          go-mockery
          cargo-nextest
          python311Packages.pytest
          python311Packages.pytest-cov
          nodePackages.jest

          # Build & Package Management
          gnumake
          cmake
          mage
          just
          poetry
          pdm
          cargo-edit
          cargo-watch
          cargo-audit

          # Code Quality Tools
          golangci-lint
          gopls
          gofumpt
          gomodifytags
          gotests
          impl
          golines
          rust-analyzer
          python311Packages.mypy
          python311Packages.flake8
          python311Packages.pylint
          python311Packages.bandit

          # Debugging Tools
          delve  # Go debugger
          gdb
          lldb
          python311Packages.ipdb

          # Documentation
          python311Packages.sphinx
          rustdoc
          godoc
        ];

        shellHook = ''
          echo "🚀 Backend Development Environment Activated!"
          echo ""
          echo "📦 Language Runtimes:"
          echo "  ✓ Go $(go version | cut -d' ' -f3)"
          echo "  ✓ Rust $(rustc --version | cut -d' ' -f2)"
          echo "  ✓ Python $(python --version | cut -d' ' -f2)"
          echo "  ✓ Node.js $(node --version)"
          echo ""
          echo "🔧 Available LSPs:"
          which gopls &>/dev/null && echo "  ✓ gopls (Go)"
          which rust-analyzer &>/dev/null && echo "  ✓ rust-analyzer (Rust)"
          which basedpyright &>/dev/null && echo "  ✓ basedpyright (Python)"
          which ruff-lsp &>/dev/null && echo "  ✓ ruff-lsp (Python linting)"
          which typescript-language-server &>/dev/null && echo "  ✓ typescript-language-server (Node.js)"
          which sqls &>/dev/null && echo "  ✓ sqls (SQL)"
          which buf-language-server &>/dev/null && echo "  ✓ buf-language-server (Protocol Buffers)"
          echo ""

          # Set up Go environment
          export GOPATH="$HOME/go"
          export PATH="$GOPATH/bin:$PATH"

          # Set up Rust environment
          export CARGO_HOME="$HOME/.cargo"
          export PATH="$CARGO_HOME/bin:$PATH"

          # Python virtual environment suggestion
          if [ ! -d ".venv" ]; then
            echo "💡 Tip: Create a Python virtual environment with: python -m venv .venv"
          else
            echo "🐍 Python venv detected at .venv"
            echo "   Activate with: source .venv/bin/activate"
          fi

          echo ""
          echo "Ready for backend development! 💻"
        '';

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = devPackages;
          inherit shellHook;

          # Environment variables
          CGO_ENABLED = "1";
          RUST_BACKTRACE = "1";
          PYTHONPATH = "";
        };

        # Language-specific shells
        devShells.go = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.golang.stable
            go
            gopls
            golangci-lint
            delve
            go-tools
            gomodifytags
            gotests
            impl
          ];
          shellHook = ''
            echo "Go development environment activated"
            go version
          '';
        };

        devShells.rust = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.rust.stable
            rustc
            cargo
            rustfmt
            clippy
            rust-analyzer
            cargo-edit
            cargo-watch
            cargo-audit
            cargo-nextest
          ];
          shellHook = ''
            echo "Rust development environment activated"
            rustc --version
            cargo --version
          '';
        };

        devShells.python = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.python.basedpyright
            lspVersions.python.ruff
            lspVersions.python.black
            python311
            python311Packages.pip
            python311Packages.setuptools
            poetry
            python311Packages.pytest
            python311Packages.mypy
            python311Packages.ipdb
          ];
          shellHook = ''
            echo "Python development environment activated"
            python --version
            echo "Use 'poetry init' or 'python -m venv .venv' to set up project"
          '';
        };

        devShells.nodejs = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.typescript.stable
            nodejs_20
            nodePackages.npm
            nodePackages.yarn
            nodePackages.pnpm
            nodePackages.typescript
            nodePackages.ts-node
            nodePackages.nodemon
            nodePackages.jest
          ];
          shellHook = ''
            echo "Node.js development environment activated"
            node --version
            npm --version
          '';
        };
      });
}