# Node.js/TypeScript Project Template

Nix flake template for Node.js/TypeScript development with typescript-language-server and common Node.js tools.

## What's Included

- **Node.js** (latest LTS from nixos-24.05)
- **typescript-language-server** (TypeScript LSP)
- **TypeScript** (compiler and type checker)
- **Package Manager Detection** (npm/yarn/pnpm/bun)
- **Optional tools** (commented in flake.nix):
  - eslint (linter)
  - prettier (formatter)
  - nodemon (auto-restart)

## Quick Start

```bash
# 1. Navigate to your project
cd ~/my-node-app

# 2. Initialize from template
nix flake init -t ~/dotfiles/nix/project-templates#nodejs-project

# 3. Create .envrc
echo "use flake" > .envrc

# 4. Allow direnv
direnv allow

# 5. Create package.json
npm init -y

# 6. Install TypeScript
npm install --save-dev typescript @types/node

# 7. Create tsconfig.json
npx tsc --init

# 8. Create index.ts
cat > index.ts << 'EOF'
const greet = (name: string): string => {
    return `Hello, ${name}!`;
};

console.log(greet("World"));
EOF

# 9. Open in Neovim
nvim index.ts
```

## Validation

### Step 1: Check Environment

```bash
# Should show project environment active
echo $NIX_LSP_ENABLED
# Expected: true

# Check Node.js version
node --version
# Expected: v20.x.x or similar

# Check TypeScript LSP
which typescript-language-server
# Expected: /nix/store/.../typescript-language-server

# Check TypeScript compiler
tsc --version
# Expected: Version 5.x.x
```

### Step 2: Test in Neovim

```bash
nvim index.ts

# In Neovim:
:LspInfo
# Expected: ts_ls (or typescript-language-server) attached

# Test LSP features:
# - K on "string" - should show type documentation
# - gd on "greet" - should go to definition
# - Save file - should show type errors if any
```

### Step 3: Test TypeScript

```bash
# Compile TypeScript
tsc index.ts

# Run compiled JavaScript
node index.js
# Expected: Hello, World!

# Or use ts-node if installed
npx ts-node index.ts
```

## Customization

### Use Latest TypeScript (Unstable)

Edit `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, nixpkgs-unstable, ... }:
    let
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.nodejs
          pkgs-unstable.nodePackages.typescript-language-server
          pkgs-unstable.nodePackages.typescript
        ];
      };
    };
}
```

### Change Package Manager

Set `NPM_PKG_MANAGER` in `flake.nix`:

```nix
shellHook = ''
  # Options: npm, yarn, pnpm, bun
  export NPM_PKG_MANAGER="pnpm"

  echo "📦 Node.js Project"
  echo "   Package Manager: $NPM_PKG_MANAGER"
'';
```

### Enable Optional Tools

Uncomment lines in `flake.nix`:

```nix
buildInputs = with pkgs.nodePackages; [
  typescript-language-server
  typescript
  # Uncomment desired tools:
  eslint          # Linter
  prettier        # Formatter
  nodemon         # Auto-restart
];
```

### Add Next.js Support

Use the `nextjs` shell from the template:

Edit `.envrc`:

```bash
# Instead of: use flake
# Use:
use flake .#nextjs
```

This includes Next.js-specific tools and optimizations.

## Common Workflows

### Initialize TypeScript Project

```bash
npm init -y
npm install --save-dev typescript @types/node
npx tsc --init
```

### Install Dependencies

```bash
npm install express
npm install --save-dev @types/express
```

### Run Development Server

```bash
# With nodemon (if enabled)
nodemon index.ts

# Or using npm scripts in package.json
npm run dev
```

### Build for Production

```bash
tsc
node dist/index.js
```

### Lint and Format

```bash
# If eslint enabled
npx eslint .

# If prettier enabled
npx prettier --write .
```

## Multiple Dev Shells

The template includes different shells for different needs:

### Default Shell

```bash
# In .envrc
use flake
# or explicitly: use flake .#default
```

**Includes**: Basic Node.js, TypeScript, typescript-language-server

### Next.js Shell

```bash
# In .envrc
use flake .#nextjs
```

**Includes**: Next.js-optimized setup with additional tools

### Production Shell

```bash
# In .envrc
use flake .#production
```

**Includes**: Production-only dependencies, no dev tools

### Test Shell

```bash
# In .envrc
use flake .#test
```

**Includes**: Testing tools (jest, etc.)

## Troubleshooting

### LSP Not Found

```bash
# Check direnv is active
direnv status

# If not, allow it
direnv allow

# Verify LSP in flake.nix
cat flake.nix | grep typescript-language-server
```

### Wrong TypeScript Version

```bash
# Check which TypeScript is active
which tsc
# Should be /nix/store/.../tsc

# Update flake
nix flake update
direnv reload
```

### node_modules Conflicts

The Nix environment and node_modules are separate:

- **Nix**: Provides TypeScript LSP and global tools
- **node_modules**: Project-specific dependencies

If LSP seems confused:

```bash
# Clear node_modules
rm -rf node_modules package-lock.json

# Reinstall
npm install

# Restart Neovim
```

### ESLint Integration

If using ESLint, create `.eslintrc.json`:

```json
{
  "extends": ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "root": true
}
```

## Next Steps

- Read [../README.md](../README.md) for inheritance patterns
- See [../../TESTING.md](../../TESTING.md) for comprehensive validation
- Check [../../QUICK_START.md](../../QUICK_START.md) for quick reference
