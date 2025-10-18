# Go Project - Override Global LSPs
# Example: Beta testing newer gopls or using older version for compatibility
{
  description = "Go project with specific LSP versions - demonstrating hybrid approach";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # Using unstable for latest gopls
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Go version selection (customize as needed)
        goVersion = pkgs.go_1_21;  # or pkgs.go_1_22, pkgs.go, etc.
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Go compiler and tools
            goVersion

            # OVERRIDE EXAMPLE: Use latest gopls from unstable
            # This overrides the global stable gopls
            gopls           # Latest gopls with new features

            # Keep using global tools
            golangci-lint   # Linter aggregator (global version)
            delve           # Debugger (global version)

            # Project-specific formatters (normally commented in global)
            gofumpt         # Stricter formatter - enabled for this project
            golines         # Long line formatter - enabled for this project

            # Additional project-specific tools
            gomodifytags    # Struct tag manipulation
            gotests         # Test generation
            impl            # Interface implementation generator
            gotools         # Various Go tools
            go-mockery      # Mock generation

            # Build tools
            gnumake
            goreleaser
            ko              # Container image builder

            # Additional development tools
            git
            gh              # GitHub CLI
            pre-commit
            direnv
          ];

          shellHook = ''
            echo "🐹 Go Project with LSP Overrides (Hybrid Approach)"
            echo "================================================="
            go version
            echo ""
            echo "🔄 LSP Overrides:"
            echo "  • gopls (latest from unstable, overriding global)"
            echo "  • golangci-lint, delve (using global versions)"
            echo ""
            echo "📦 Project-specific formatters:"
            echo "  • gofumpt (stricter formatting enabled)"
            echo "  • golines (long line formatting enabled)"
            echo ""
            echo "PATH precedence ensures project tools override global"
            echo ""

            # Set up Go module if not exists
            if [ ! -f go.mod ]; then
              echo "💡 No go.mod found. Initialize with:"
              echo "   go mod init github.com/user/project"
            else
              # Download dependencies
              echo "📦 Downloading Go modules..."
              go mod download 2>/dev/null || true
            fi

            # Set up pre-commit if config exists
            if [ -f .pre-commit-config.yaml ]; then
              pre-commit install 2>/dev/null || true
            fi
          '';

          # Go environment variables
          GOPATH = "$HOME/go";
          CGO_ENABLED = "1";  # Enable CGO for certain packages
          GO111MODULE = "on";
          GOPROXY = "https://proxy.golang.org,direct";
          GOSUMDB = "sum.golang.org";
          GOPRIVATE = "github.com/your-org/*";  # Customize for private repos
        };

        # Alternative shell for testing
        devShells.test = pkgs.mkShell {
          buildInputs = with pkgs; [
            goVersion
            gopls
            gotests
            go-mockery
            ginkgo
            richgo  # Colored test output
          ];

          shellHook = ''
            echo "🧪 Go Test Environment"
            go version
            echo "Run tests with: richgo test ./..."
          '';
        };

        # Shell for building containers
        devShells.build = pkgs.mkShell {
          buildInputs = with pkgs; [
            goVersion
            ko
            docker
            goreleaser
          ];

          shellHook = ''
            echo "📦 Go Build Environment"
            echo "Build with ko: ko build ."
            echo "Release with: goreleaser release --snapshot"
          '';
        };
      });
}