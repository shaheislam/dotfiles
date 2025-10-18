# Frontend Development Stack Flake Template
# Includes React, Vue, TypeScript, and modern web development tools

{
  description = "Frontend development environment with modern web tooling";

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
          # LSPs for Frontend Development
          lspVersions.typescript.stable      # TypeScript/JavaScript LSP
          lspVersions.typescript.prettier    # Prettier formatter
          lspVersions.typescript.eslint      # ESLint for linting
          nodePackages.vscode-langservers-extracted  # HTML/CSS/JSON LSPs
          nodePackages.svelte-language-server
          nodePackages.vue-language-server
          tailwindcss-language-server
          emmet-language-server
          nodePackages.graphql-language-service-cli
          lspVersions.json.stable
          lspVersions.yaml.stable
          lspVersions.markdown.marksman

          # JavaScript/TypeScript Runtime
          nodejs_20
          nodePackages.npm
          nodePackages.yarn
          nodePackages.pnpm
          bun
          deno

          # Build Tools
          nodePackages.webpack
          nodePackages.webpack-cli
          nodePackages.vite
          nodePackages.parcel
          nodePackages.rollup
          nodePackages.esbuild
          nodePackages.turbo

          # Frontend Frameworks & Libraries (CLI tools)
          nodePackages.create-react-app
          nodePackages.create-next-app
          nodePackages."@vue/cli"
          nodePackages."@angular/cli"
          nodePackages.svelte-check

          # CSS Tools
          nodePackages.sass
          nodePackages.less
          nodePackages.postcss
          nodePackages.postcss-cli
          nodePackages.tailwindcss
          nodePackages.stylelint

          # Testing Tools
          nodePackages.jest
          nodePackages.mocha
          nodePackages."@vitest/ui"
          nodePackages."@testing-library/react"
          nodePackages."@playwright/test"
          cypress

          # Code Quality
          nodePackages.eslint
          nodePackages.prettier
          nodePackages.typescript
          nodePackages.ts-node
          nodePackages.tslib
          nodePackages.tslint

          # Development Tools
          nodePackages.nodemon
          nodePackages.concurrently
          nodePackages.cross-env
          nodePackages.dotenv-cli
          nodePackages.serve
          nodePackages.http-server
          nodePackages.live-server

          # API Development
          nodePackages.json-server
          nodePackages.graphql
          nodePackages."@graphql-codegen/cli"
          nodePackages."@apollo/client"
          nodePackages.axios

          # Documentation
          nodePackages.jsdoc
          nodePackages.typedoc
          storybook-cli

          # Performance Tools
          lighthouse
          nodePackages.bundlesize
          nodePackages.webpack-bundle-analyzer

          # Browser Testing
          chromium
          firefox
          playwright-driver
        ];

        shellHook = ''
          echo "🎨 Frontend Development Environment Activated!"
          echo ""
          echo "📦 Runtime Versions:"
          echo "  ✓ Node.js $(node --version)"
          echo "  ✓ npm $(npm --version)"
          echo "  ✓ yarn $(yarn --version 2>/dev/null || echo 'installed')"
          echo "  ✓ pnpm $(pnpm --version 2>/dev/null || echo 'installed')"
          which bun &>/dev/null && echo "  ✓ Bun $(bun --version)"
          which deno &>/dev/null && echo "  ✓ Deno $(deno --version | head -1 | cut -d' ' -f2)"
          echo ""
          echo "🔧 Available LSPs:"
          which typescript-language-server &>/dev/null && echo "  ✓ typescript-language-server"
          which vscode-html-language-server &>/dev/null && echo "  ✓ HTML Language Server"
          which vscode-css-language-server &>/dev/null && echo "  ✓ CSS Language Server"
          which tailwindcss-language-server &>/dev/null && echo "  ✓ Tailwind CSS Language Server"
          which svelte-language-server &>/dev/null && echo "  ✓ Svelte Language Server"
          which vue-language-server &>/dev/null && echo "  ✓ Vue Language Server"
          which emmet-language-server &>/dev/null && echo "  ✓ Emmet Language Server"
          which prettier &>/dev/null && echo "  ✓ Prettier"
          which eslint &>/dev/null && echo "  ✓ ESLint"
          echo ""

          # Check for package.json
          if [ -f "package.json" ]; then
            echo "📄 package.json detected"

            # Detect package manager
            if [ -f "pnpm-lock.yaml" ]; then
              echo "📦 Using pnpm (lockfile detected)"
              alias npm="pnpm"
              alias npx="pnpm exec"
            elif [ -f "yarn.lock" ]; then
              echo "📦 Using yarn (lockfile detected)"
              alias npm="yarn"
              alias npx="yarn exec"
            elif [ -f "package-lock.json" ]; then
              echo "📦 Using npm (lockfile detected)"
            elif [ -f "bun.lockb" ]; then
              echo "📦 Using bun (lockfile detected)"
              alias npm="bun"
              alias npx="bun x"
            fi

            # Check for common scripts
            echo ""
            echo "📜 Available scripts:"
            node -e "const p=require('./package.json'); if(p.scripts) Object.keys(p.scripts).forEach(s => console.log('  npm run ' + s));" 2>/dev/null || true
          else
            echo "💡 No package.json found. Initialize a project with:"
            echo "  - npm init"
            echo "  - pnpm create vite"
            echo "  - yarn create next-app"
            echo "  - bunx create-react-app"
          fi

          echo ""
          echo "Ready for frontend development! 🚀"
        '';

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = devPackages;
          inherit shellHook;

          # Environment variables
          NODE_ENV = "development";
          BROWSER = "none"; # Prevent auto-opening browser
        };

        # Framework-specific shells
        devShells.react = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.typescript.stable
            nodejs_20
            nodePackages.npm
            nodePackages.create-react-app
            nodePackages."@testing-library/react"
            nodePackages.eslint
            nodePackages.prettier
          ];
          shellHook = ''
            echo "⚛️  React development environment activated"
            echo "Create new app with: npx create-react-app my-app"
          '';
        };

        devShells.vue = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.typescript.stable
            nodejs_20
            nodePackages.npm
            nodePackages."@vue/cli"
            nodePackages.vue-language-server
            nodePackages.vite
          ];
          shellHook = ''
            echo "💚 Vue development environment activated"
            echo "Create new app with: npm create vue@latest"
          '';
        };

        devShells.nextjs = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.typescript.stable
            nodejs_20
            nodePackages.npm
            nodePackages.create-next-app
            nodePackages.eslint
            nodePackages.prettier
            tailwindcss-language-server
          ];
          shellHook = ''
            echo "▲ Next.js development environment activated"
            echo "Create new app with: npx create-next-app@latest"
          '';
        };

        devShells.minimal = pkgs.mkShell {
          buildInputs = with pkgs; [
            lspVersions.typescript.stable
            nodejs_20
            nodePackages.npm
            nodePackages.prettier
            nodePackages.eslint
          ];
          shellHook = ''
            echo "Minimal frontend environment activated"
          '';
        };
      });
}