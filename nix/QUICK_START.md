# LSP Inheritance Quick Start

Fast reference for using the Nix LSP inheritance system.

## TL;DR

```bash
# Use a template
cd ~/my-project
nix flake init -t ~/dotfiles/nix/project-templates#go-project
direnv allow

# Verify it works
which gopls          # Should be /nix/store/.../gopls
echo $NIX_LSP_ENABLED  # Should be "true"
nvim main.go         # LSP should attach automatically
```

## Common Commands

### Check Current Environment

```bash
# Are you in a project with Nix LSP?
echo $NIX_LSP_ENABLED        # "true" = project, empty = global

# Which LSP binary is active?
which gopls                  # /nix/store/... = project, ~/.nix-profile/... = global

# What version?
gopls version

# Check PATH order
echo $PATH | tr ':' '\n' | head -3   # Project should be first
```

### direnv Operations

```bash
# Allow new .envrc (required first time)
direnv allow

# Reload after flake.nix changes
direnv reload

# Check direnv status
direnv status

# Temporarily disable direnv
direnv deny
```

### Nix Flake Operations

```bash
# Update flake dependencies
nix flake update

# Check flake syntax
nix flake check

# Show flake info
nix flake show

# Enter development shell manually (without direnv)
nix develop
```

### Neovim LSP Commands

```vim
" Check LSP status
:LspInfo

" Show attached clients
:lua vim.print(vim.lsp.get_clients())

" Check environment
:lua print(vim.env.NIX_LSP_ENABLED)
:lua print(vim.env.IN_NIX_SHELL)

" Restart LSP
:LspRestart

" Show LSP binary path
:lua print(vim.lsp.get_clients()[1].config.cmd[1])
```

## Template Selection Guide

| Template | Use When | LSPs Included |
|----------|----------|---------------|
| `go-project` | Go development | gopls, golangci-lint-langserver |
| `python-project` | Python with type checking | basedpyright (or pyright), ruff-lsp |
| `nodejs-project` | Node.js/TypeScript | typescript-language-server, eslint |
| `terraform-project` | Infrastructure as Code | terraform-ls |

### Using Templates

```bash
# Initialize from template
cd ~/my-project
nix flake init -t ~/dotfiles/nix/project-templates#TEMPLATE_NAME

# Available templates: go-project, python-project, nodejs-project, terraform-project
```

## Inheritance Patterns Cheat Sheet

### Pattern 1: Use Everything from Global + Extras

```nix
{
  inputs.dotfiles.url = "path:/Users/shahe/dotfiles/nix/global";

  devShells.default = pkgs.mkShell {
    inputsFrom = [ dotfiles.outputs.devShells.${system}.default ];
    buildInputs = [ pkgs.extra-package ];  # Add extras only
  };
}
```

### Pattern 2: Override ONE LSP

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  devShells.default = pkgs.mkShell {
    buildInputs = [
      pkgs-unstable.gopls  # Override just gopls
      # All other LSPs come from global
    ];
  };
}
```

### Pattern 3: Complete Custom Stack

```nix
{
  devShells.default = pkgs.mkShell {
    buildInputs = [
      pkgs.tool1
      pkgs.tool2
      # Explicitly list everything, no inheritance
    ];
  };
}
```

## Validation One-Liners

```bash
# Quick test: Are projects isolated?
cd ~/project-a && gopls version && cd ~/project-b && gopls version
# Should show DIFFERENT versions

# Quick test: Does global fallback work?
cd ~ && echo $NIX_LSP_ENABLED
# Should be empty

# Quick test: Run automated suite
~/dotfiles/scripts/test-lsp-inheritance.sh
# Should pass all tests

# Quick test: Neovim detects environment
nvim -c 'lua print(vim.env.NIX_LSP_ENABLED or "GLOBAL")' -c 'q'
# Should print "true" in project, "GLOBAL" elsewhere
```

## Troubleshooting Quick Fixes

### direnv not loading

```bash
direnv allow
direnv reload
```

### Wrong LSP version

```bash
# Update flake lock
nix flake update
direnv reload
```

### Neovim using wrong LSP

```bash
# Restart Neovim (it inherits environment at startup)
# In Neovim: :LspRestart
```

### Environment not unloading

```bash
cd ~  # Leave project
direnv reload
echo $NIX_LSP_ENABLED  # Should be empty now
```

## Directory Structure Reference

```
~/dotfiles/nix/
├── README.md              # Full architecture guide
├── TESTING.md             # Step-by-step validation
├── QUICK_START.md         # This file
├── lsp-versions.nix       # LSP version registry
├── global/
│   └── flake.nix          # Global baseline
└── project-templates/
    ├── go-project/
    │   └── flake.nix
    ├── python-project/
    │   └── flake.nix
    ├── nodejs-project/
    │   └── flake.nix
    └── terraform-project/
        └── flake.nix
```

## Environment Variables Reference

| Variable | Set By | Meaning |
|----------|--------|---------|
| `NIX_LSP_ENABLED` | Project flake.nix | "true" = project LSP active |
| `IN_NIX_SHELL` | Nix | Set when in `nix develop` shell |
| `DIRENV_DIR` | direnv | Current direnv-managed directory |
| `PATH` | Nix + direnv | Project bins first, then global |

## Quick Examples

### Example 1: Create Go Project with Latest gopls

```bash
mkdir ~/my-go-app && cd ~/my-go-app
git init

cat > flake.nix << 'EOF'
{
  description = "My Go App";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }: {
    devShells.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
      buildInputs = [ nixpkgs.legacyPackages.aarch64-darwin.go
                      nixpkgs.legacyPackages.aarch64-darwin.gopls ];
      NIX_LSP_ENABLED = "true";
    };
  };
}
EOF

echo "use flake" > .envrc
direnv allow
nvim main.go  # Ready!
```

### Example 2: Python Project with pyright (not basedpyright)

```bash
cd ~/my-python-app
nix flake init -t ~/dotfiles/nix/project-templates#python-project

# Edit flake.nix to replace basedpyright with pyright
# Change:  pkgs.basedpyright
# To:      pkgs.nodePackages.pyright

direnv reload
nvim app.py
```

### Example 3: Verify Three-Tier System

```bash
# Terminal 1: Project A
cd ~/test-project-a
echo "Project A: $(gopls version)"

# Terminal 2: Project B
cd ~/test-project-b
echo "Project B: $(gopls version)"

# Terminal 3: Global
cd ~/Downloads
echo "Global: $(gopls version)"

# All three should show DIFFERENT setups
```

## Further Reading

- **Full Guide**: [README.md](./README.md)
- **Testing**: [TESTING.md](./TESTING.md)
- **Templates**: [project-templates/README.md](./project-templates/README.md)
- **Version Registry**: [lsp-versions.nix](./lsp-versions.nix)

## Need Help?

1. Check [TESTING.md](./TESTING.md) for detailed validation procedures
2. Review [README.md](./README.md) for architecture explanation
3. Examine template examples in `project-templates/`
4. Run automated test: `~/dotfiles/scripts/test-lsp-inheritance.sh`
