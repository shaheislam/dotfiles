# Project Templates

Ready-to-use Nix flake templates for different language environments with LSP inheritance support.

## Available Templates

| Template | Languages | LSPs Included | Use Case |
|----------|-----------|---------------|----------|
| [go-project](./go-project/) | Go | gopls, golangci-lint-langserver | Go development with linting |
| [python-project](./python-project/) | Python | basedpyright/pyright, ruff-lsp | Python with type checking |
| [nodejs-project](./nodejs-project/) | JavaScript/TypeScript | typescript-language-server, eslint | Node.js/TypeScript development |
| [terraform-project](./terraform-project/) | HCL | terraform-ls | Infrastructure as Code |

## Quick Start

```bash
# Navigate to your project directory
cd ~/my-project

# Initialize from template
nix flake init -t ~/dotfiles/nix/project-templates#TEMPLATE_NAME

# Replace TEMPLATE_NAME with: go-project, python-project, nodejs-project, or terraform-project

# Allow direnv
direnv allow

# Start coding!
nvim main.go  # or main.py, index.ts, main.tf
```

## Template Structure

Each template includes:

-  **flake.nix** - Nix flake configuration with LSP packages
- **.envrc** - direnv configuration (created by you)
- **README.md** - Template-specific usage and validation guide

## Validation

After initializing from a template, verify it works:

### Quick Validation

```bash
# Check environment is active
echo $NIX_LSP_ENABLED
# Expected: true

# Check LSP is from Nix
which gopls  # or pyright-langserver, typescript-language-server, terraform-ls
# Expected: /nix/store/.../bin/...

# Test in Neovim
nvim main.go
# :LspInfo should show attached LSP
```

### Comprehensive Validation

See the template-specific README for detailed validation procedures:

- [go-project/README.md](./go-project/README.md)
- [python-project/README.md](./python-project/README.md)
- [nodejs-project/README.md](./nodejs-project/README.md)

Or run the automated test suite:

```bash
~/dotfiles/scripts/test-lsp-inheritance.sh
```

## Customizing Templates

### Override LSP Version

To use a different LSP version, modify the flake.nix:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";        # Stable
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";  # Latest
  };

  outputs = { nixpkgs, nixpkgs-unstable, ... }:
    devShells.default = pkgs.mkShell {
      buildInputs = [
        pkgs.go                    # Stable Go
        pkgs-unstable.gopls        # Latest gopls
      ];
    };
}
```

### Add Additional Tools

Simply add to `buildInputs`:

```nix
buildInputs = with pkgs; [
  gopls
  golangci-lint
  # Add more tools:
  delve          # Debugger
  air            # Live reload
  mockgen        # Mock generator
];
```

### Inherit from Global

To inherit most packages from global and add only a few extras:

```nix
{
  inputs.dotfiles.url = "path:/Users/shahe/dotfiles/nix/global";

  outputs = { dotfiles, ... }:
    devShells.default = pkgs.mkShell {
      inputsFrom = [ dotfiles.outputs.devShells.${system}.default ];

      buildInputs = [
        pkgs.postgresql  # Add just PostgreSQL, keep all global LSPs
      ];
    };
}
```

See [with-inheritance.nix](./with-inheritance.nix) for more patterns.

## Common Workflows

### Create New Go Project

```bash
mkdir ~/my-go-app && cd ~/my-go-app
git init

nix flake init -t ~/dotfiles/nix/project-templates#go-project
echo "use flake" > .envrc
direnv allow

# Create main.go
cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF

# Open in Neovim
nvim main.go
# LSP should attach automatically
```

### Create Python Project with Specific Python Version

```bash
cd ~/my-python-app
nix flake init -t ~/dotfiles/nix/project-templates#python-project

# Edit flake.nix to change Python version
# Change: pkgs.python312
# To:     pkgs.python311

echo "use flake" > .envrc
direnv allow

nvim app.py
```

### Create Node.js Project with Specific Package Manager

```bash
cd ~/my-node-app
nix flake init -t ~/dotfiles/nix/project-templates#nodejs-project

# Edit flake.nix to set NPM_PKG_MANAGER
# Options: npm, yarn, pnpm, bun

echo "use flake" > .envrc
direnv allow

nvim index.ts
```

## Troubleshooting

### LSP Not Found

**Problem**: `gopls: command not found` in project

**Solution**:
```bash
# Check direnv is active
direnv status

# If not, allow it
direnv allow

# Verify flake.nix has the LSP
cat flake.nix | grep gopls
```

### Wrong LSP Version

**Problem**: Project uses global LSP instead of project-specific

**Solution**:
```bash
# Update flake lock
nix flake update

# Reload direnv
direnv reload

# Check PATH order
echo $PATH | tr ':' '\n' | head -3
# /nix/store path should be FIRST
```

### Neovim Not Detecting LSP

**Problem**: `:LspInfo` shows no clients attached

**Solution**:
```bash
# Restart Neovim after direnv changes
# Check environment in Neovim:
# :lua print(vim.env.NIX_LSP_ENABLED)
# Should print "true"

# Check LSP config
nvim ~/.config/nvim/lua/plugins/lsp.lua
```

## Template Development

### Creating New Template

1. Create directory: `mkdir -p new-template`
2. Create `flake.nix` with LSP packages
3. Add to `flake.nix` outputs in parent directory
4. Create template-specific README.md
5. Test validation procedures

### Template Checklist

- [ ] `flake.nix` with correct LSP packages
- [ ] `NIX_LSP_ENABLED = "true"` in shellHook
- [ ] Helpful `shellHook` output showing versions
- [ ] Template-specific README.md
- [ ] Validation procedures documented
- [ ] Example code files (optional)

## Further Reading

- [../README.md](../README.md) - LSP inheritance architecture
- [../TESTING.md](../TESTING.md) - Comprehensive validation guide
- [../QUICK_START.md](../QUICK_START.md) - Quick reference
- [with-inheritance.nix](./with-inheritance.nix) - Inheritance patterns
