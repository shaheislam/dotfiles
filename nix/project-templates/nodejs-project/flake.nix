# Node.js/TypeScript Project - Override Global LSPs
# Example: Testing beta TypeScript features or using specific versions
{
  description = "Node.js project with specific LSP versions - demonstrating hybrid approach";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # Using unstable for latest TypeScript
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Node version selection
        nodeVersion = pkgs.nodejs_20;  # or nodejs_18, nodejs_21
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js and package managers
            nodeVersion
            nodePackages.npm
            nodePackages.yarn
            nodePackages.pnpm
            bun  # Alternative JS runtime

            # OVERRIDE EXAMPLE: Latest TypeScript & LSP from unstable
            # This overrides the global stable versions
            nodePackages.typescript  # Latest TypeScript compiler
            nodePackages.typescript-language-server  # Latest TS LSP

            # Keep using global ESLint/JSON/HTML LSPs
            nodePackages.vscode-langservers-extracted  # HTML/CSS/JSON
            nodePackages."@tailwindcss/language-server"

            # Project-specific formatters (normally commented in global)
            nodePackages.prettier  # Enabled for this project
            nodePackages.eslint  # Linting enabled

            # Development tools
            nodePackages.nodemon
            nodePackages.ts-node
            nodePackages.tsx  # TypeScript execute
            nodePackages.concurrently
            nodePackages.cross-env

            # Testing
            nodePackages.jest
            nodePackages."@vitest/ui"
            nodePackages."@playwright/test"

            # Build tools
            nodePackages.webpack
            nodePackages.webpack-cli
            nodePackages.vite
            nodePackages.esbuild
            nodePackages.turbo

            # Additional tools
            git
            direnv
            pre-commit
            jq  # For package.json manipulation
          ];

          shellHook = ''
            echo "⚡ Node.js Project with LSP Overrides (Hybrid Approach)"
            echo "===================================================="
            node --version
            echo "npm $(npm --version)"
            echo ""
            echo "🔄 LSP Overrides:"
            echo "  • typescript-language-server (latest from unstable)"
            echo "  • typescript compiler (latest version)"
            echo "  • ESLint/JSON/HTML LSPs (using global versions)"
            echo ""
            echo "📦 Project-specific tools:"
            echo "  • prettier (formatting enabled)"
            echo "  • eslint (linting enabled)"
            echo ""

            # Detect package manager
            if [ -f "bun.lockb" ]; then
              echo "📦 Using Bun (lockfile detected)"
              alias npm="bun"
              alias npx="bun x"
              alias yarn="bun"
            elif [ -f "pnpm-lock.yaml" ]; then
              echo "📦 Using pnpm (lockfile detected)"
              alias npm="pnpm"
              alias npx="pnpm exec"
              alias yarn="pnpm"
            elif [ -f "yarn.lock" ]; then
              echo "📦 Using Yarn (lockfile detected)"
              alias npm="yarn"
              alias npx="yarn exec"
            elif [ -f "package-lock.json" ]; then
              echo "📦 Using npm (lockfile detected)"
            else
              echo "📦 No lockfile detected, using npm by default"
            fi

            echo ""
            echo "Available tools:"
            echo "  • typescript-language-server (LSP)"
            echo "  • eslint, prettier (linting/formatting)"
            echo "  • jest, vitest, playwright (testing)"
            echo "  • webpack, vite, esbuild (bundling)"
            echo "  • nodemon, ts-node (development)"
            echo ""

            # Check for package.json
            if [ -f "package.json" ]; then
              # Get project info
              PROJECT_NAME=$(node -p "require('./package.json').name" 2>/dev/null || echo "unknown")
              PROJECT_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
              echo "📁 Project: $PROJECT_NAME@$PROJECT_VERSION"

              # Check if node_modules exists
              if [ ! -d "node_modules" ]; then
                echo ""
                echo "⚠️  No node_modules found. Install dependencies with:"
                if [ -f "bun.lockb" ]; then
                  echo "   bun install"
                elif [ -f "pnpm-lock.yaml" ]; then
                  echo "   pnpm install"
                elif [ -f "yarn.lock" ]; then
                  echo "   yarn install"
                else
                  echo "   npm install"
                fi
              else
                echo "✓ node_modules present"
              fi

              # List available scripts
              echo ""
              echo "📜 Available scripts:"
              node -e "
                const scripts = require('./package.json').scripts || {};
                const maxLen = Math.max(...Object.keys(scripts).map(s => s.length));
                Object.entries(scripts).forEach(([name, cmd]) => {
                  const shortCmd = cmd.length > 50 ? cmd.substring(0, 47) + '...' : cmd;
                  console.log('  npm run ' + name.padEnd(maxLen + 2) + '# ' + shortCmd);
                });
              " 2>/dev/null || echo "  (no scripts defined)"
            else
              echo "💡 No package.json found. Initialize with:"
              echo "   npm init -y"
              echo "   # or for specific frameworks:"
              echo "   npm create vite@latest"
              echo "   npx create-next-app@latest"
              echo "   npx create-react-app my-app"
            fi

            # TypeScript check
            if [ -f "tsconfig.json" ]; then
              echo ""
              echo "📘 TypeScript configuration detected"
              TS_VERSION=$(npx tsc --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
              echo "   TypeScript version: $TS_VERSION"
            fi

            # Set up pre-commit if config exists
            if [ -f ".pre-commit-config.yaml" ]; then
              pre-commit install 2>/dev/null || true
            fi

            # Set Node options for better development experience
            export NODE_OPTIONS="--max-old-space-size=4096"
          '';

          # Environment variables
          NODE_ENV = "development";
          BROWSER = "none";  # Prevent auto-opening browser
          FORCE_COLOR = "1";  # Force colored output in terminals

          # Nix LSP detection (for Neovim integration)
          NIX_LSP_ENABLED = "true";
        };

        # Production build shell
        devShells.production = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodeVersion
            nodePackages.npm
          ];

          shellHook = ''
            echo "📦 Production Build Environment"
            export NODE_ENV=production
            echo "NODE_ENV=production"
          '';

          NODE_ENV = "production";
        };

        # Testing shell
        devShells.test = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodeVersion
            nodePackages.npm
            nodePackages.jest
            nodePackages."@vitest/ui"
            nodePackages."@playwright/test"
            chromium
            firefox
          ];

          shellHook = ''
            echo "🧪 Testing Environment"
            echo "Available test runners:"
            echo "  • jest"
            echo "  • vitest"
            echo "  • playwright"
            export NODE_ENV=test
          '';

          NODE_ENV = "test";
        };

        # Next.js specific shell
        devShells.nextjs = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodeVersion
            nodePackages.npm
            nodePackages.yarn
            nodePackages.pnpm
            nodePackages.typescript
            nodePackages.typescript-language-server
            nodePackages."@tailwindcss/language-server"
            nodePackages.eslint
            nodePackages.prettier
          ];

          shellHook = ''
            echo "▲ Next.js Development Environment"
            echo ""
            if [ ! -f "next.config.js" ] && [ ! -f "next.config.mjs" ]; then
              echo "💡 Create a new Next.js app with:"
              echo "   npx create-next-app@latest ."
            else
              echo "✓ Next.js project detected"
              echo "   Dev server: npm run dev"
              echo "   Build: npm run build"
              echo "   Start: npm run start"
            fi
          '';
        };
      });
}