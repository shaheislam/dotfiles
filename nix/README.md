# Nix LSP Inheritance System

Comprehensive guide to the Nix-based LSP (Language Server Protocol) inheritance system in this dotfiles repository.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [Inheritance Patterns](#inheritance-patterns)
- [Testing & Validation](#testing--validation)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting](#troubleshooting)

## Overview

This repository implements a **three-tier LSP configuration system** that allows you to:

✅ Use a **global baseline** of LSPs available everywhere
✅ **Override LSP versions** per-project using Nix flakes
✅ **Isolate projects** from each other (no conflicts)
✅ **Pin specific versions** for legacy compatibility
✅ **Mix and match** different LSP stacks per project

### Why This Matters

**Problem:** Different projects need different LSP versions:
- Legacy project needs `gopls` v0.11
- New project needs `gopls` v0.16
- Quick scripts need *something* that just works

**Solution:** Three-tier inheritance with automatic PATH precedence.

## Architecture

```
┌─────────────────────────────────────────────┐
│ Layer 1: Global Baseline                    │
│ ~/.nix-profile/bin/*                        │
│ Always available, managed by home-manager   │
└──────────────────┬──────────────────────────┘
                   ↓ overridden by
┌─────────────────────────────────────────────┐
│ Layer 2: Project Override (Nix Flake)       │
│ /nix/store/.../bin/* (per-project)          │
│ Activated by direnv when entering directory │
└──────────────────┬──────────────────────────┘
                   ↓ configured by
┌─────────────────────────────────────────────┐
│ Layer 3: Neovim LSP Config                  │
│ Detects environment and uses correct binary │
│ Automatically falls back to global if needed│
└─────────────────────────────────────────────┘
```

### Key Files

| File | Purpose |
|------|---------|
| `nix/lsp-versions.nix` | Centralized LSP version registry |
| `nix/global/flake.nix` | Global baseline environment |
| `nix/project-templates/*/flake.nix` | Project-specific overrides |
| `.config/nvim/lua/plugins/lsp.lua` | Neovim LSP detection logic |

## How It Works

### 1. Environment Detection

When you enter a directory with a `flake.nix`, direnv automatically:
1. Activates the Nix shell defined in the flake
2. Prepends project-specific `/nix/store/.../bin` to PATH
3. Sets `IN_NIX_SHELL=true` and `NIX_LSP_ENABLED=true`

### 2. PATH Precedence

```bash
# In project directory with flake.nix
$ echo $PATH
/nix/store/abc123-gopls-0.16/bin:...    # Project-specific (FIRST!)
/home/user/.nix-profile/bin:...         # Global fallback (SECOND)

# In random directory (no flake.nix)
$ echo $PATH
/home/user/.nix-profile/bin:...         # Global only
```

### 3. Neovim Detection

Neovim's LSP config checks:
```lua
local in_nix_shell = os.getenv("IN_NIX_SHELL") ~= nil
local nix_lsp_enabled = os.getenv("NIX_LSP_ENABLED") == "true"

if command_exists("gopls") then
  if in_nix_shell or nix_lsp_enabled then
    -- Use project-specific gopls
  else
    -- Use global gopls
  end
end
```

## Quick Start

### Using an Existing Template

```bash
# 1. Navigate to your project
cd ~/my-go-project

# 2. Initialize from template
nix flake init -t ~/dotfiles/nix/project-templates#go-project

# 3. Allow direnv (one-time)
direnv allow

# 4. Verify it works
which gopls
# Expected: /nix/store/.../gopls

echo $NIX_LSP_ENABLED
# Expected: true

# 5. Open Neovim
nvim main.go
# LSP should attach automatically with project-specific gopls
```

### Available Templates

| Template | LSPs Included | Use Case |
|----------|---------------|----------|
| `go-project` | gopls, golangci-lint-langserver | Go development |
| `python-project` | basedpyright/pyright, ruff-lsp | Python development |
| `nodejs-project` | typescript-language-server, eslint | Node.js/TypeScript |
| `terraform-project` | terraform-ls | Infrastructure as Code |

## Inheritance Patterns

See `project-templates/with-inheritance.nix` for detailed examples of four patterns:

### 1. Default Inheritance (Recommended)

**Use when:** You want everything from global + a few extras

```nix
{
  inputs.dotfiles.url = "path:/Users/shahe/dotfiles/nix/global";

  outputs = { nixpkgs, dotfiles, ... }: {
    devShells.default = pkgs.mkShell {
      inputsFrom = [ dotfiles.outputs.devShells.${system}.default ];

      buildInputs = [
        pkgs.postgresql  # Add just PostgreSQL, keep all global LSPs
      ];
    };
  };
}
```

### 2. Selective Override

**Use when:** You want to replace ONE specific LSP version

```nix
{
  outputs = { nixpkgs, nixpkgs-unstable, ... }: {
    devShells.default = pkgs.mkShell {
      buildInputs = [
        # Override: Use unstable gopls for new features
        pkgs-unstable.gopls

        # All other LSPs come from global (via PATH)
      ];
    };
  };
}
```

### 3. Complete Override

**Use when:** Project needs a completely different LSP stack

```nix
{
  outputs = { nixpkgs, ... }: {
    devShells.default = pkgs.mkShell {
      buildInputs = [
        # Override: Use pyright instead of basedpyright
        pkgs.nodePackages.pyright
        pkgs.ruff-lsp
        # No inheritance - completely custom stack
      ];
    };
  };
}
```

### 4. Version Pinning (Legacy Projects)

**Use when:** Project requires specific old version

```nix
{
  inputs.nixpkgs-legacy.url = "github:NixOS/nixpkgs/abc123";

  outputs = { nixpkgs-legacy, ... }: {
    devShells.default = pkgs.mkShell {
      buildInputs = [
        nixpkgs-legacy.legacyPackages.${system}.gopls  # Pinned version
      ];
    };
  };
}
```

## Testing & Validation

See `TESTING.md` for comprehensive step-by-step validation procedures.

### Quick Validation

```bash
# Run automated test
~/dotfiles/scripts/test-lsp-inheritance.sh

# Manual quick check
cd ~/my-project && direnv allow
which gopls    # Should show /nix/store/... path
echo $NIX_LSP_ENABLED  # Should be "true"

cd ~
which gopls    # Should show ~/.nix-profile/bin/gopls
echo $NIX_LSP_ENABLED  # Should be empty
```

### In Neovim

```vim
" Check active LSP
:LspInfo

" Check environment
:lua print(vim.env.IN_NIX_SHELL)
:lua print(vim.env.NIX_LSP_ENABLED)

" Check which binary is being used
:lua print(vim.lsp.get_clients()[1].config.cmd[1])
```

## Common Scenarios

### Scenario 1: Test Two Different gopls Versions

```bash
# Project A: Stable gopls
cd ~/project-a
cat flake.nix
# buildInputs = [ pkgs.gopls ];  # Uses stable from lsp-versions.nix

# Project B: Unstable gopls
cd ~/project-b
cat flake.nix
# buildInputs = [ pkgs-unstable.gopls ];  # Uses latest

# Verify different versions
cd ~/project-a && direnv allow && gopls version
# v0.15.3

cd ~/project-b && direnv allow && gopls version
# v0.16.0
```

### Scenario 2: Python - Switch Between pyright and basedpyright

```bash
# Project A: Use basedpyright (default)
cd ~/project-a
cat flake.nix
# buildInputs = [ pkgs.basedpyright ];

# Project B: Use pyright (override)
cd ~/project-b
cat flake.nix
# buildInputs = [ pkgs.nodePackages.pyright ];

# Both work independently
```

### Scenario 3: Global Fallback

```bash
# Any directory without flake.nix uses global
cd ~/Downloads
which gopls
# /Users/shahe/.nix-profile/bin/gopls

nvim test.go
# LSP still works using global version
```

## Troubleshooting

### LSP Not Found

**Problem:** `gopls: command not found`

**Solution:**
```bash
# Check if global LSPs are installed
ls ~/.nix-profile/bin/gopls

# If missing, rebuild home-manager
home-manager switch

# Or install globally
nix-env -iA nixpkgs.gopls
```

### Wrong LSP Version

**Problem:** Using global instead of project-specific

**Solution:**
```bash
# Check direnv is active
direnv status

# If not allowed
direnv allow

# Check PATH order
echo $PATH | tr ':' '\n' | head -5
# Project /nix/store path should be FIRST
```

### Environment Variables Not Set

**Problem:** `NIX_LSP_ENABLED` is empty

**Solution:**
```bash
# Check flake.nix has the variable
cat flake.nix | grep NIX_LSP_ENABLED

# Should have:
# NIX_LSP_ENABLED = "true";

# Reload direnv
direnv reload
```

### Neovim Not Using Nix LSP

**Problem:** `:LspInfo` shows system LSP instead of Nix

**Solution:**
1. Check environment in Neovim: `:lua print(vim.env.IN_NIX_SHELL)`
2. Verify command path: `:lua print(vim.lsp.get_clients()[1].config.cmd[1])`
3. Restart Neovim after direnv changes
4. Check `.config/nvim/lua/plugins/lsp.lua` for detection logic

### Project Isolation Not Working

**Problem:** Project A's LSP leaks into Project B

**Solution:**
```bash
# Each project should have its own flake.nix
ls ~/project-a/flake.nix  # Should exist
ls ~/project-b/flake.nix  # Should exist

# Direnv should unload when leaving directory
cd ~/project-a && echo $NIX_LSP_ENABLED  # "true"
cd ~ && echo $NIX_LSP_ENABLED            # empty
cd ~/project-b && echo $NIX_LSP_ENABLED  # "true"
```

## Additional Resources

- [TESTING.md](./TESTING.md) - Comprehensive validation procedures
- [QUICK_START.md](./QUICK_START.md) - Quick reference card
- [project-templates/README.md](./project-templates/README.md) - Template usage guide
- [lsp-versions.nix](./lsp-versions.nix) - Available LSP versions

## Contributing

When adding new LSPs:
1. Add to `lsp-versions.nix` with version profiles
2. Update `global/flake.nix` to include in baseline
3. Add to `.config/nvim/lua/plugins/lsp.lua` for Neovim detection
4. Create/update project template if language-specific
5. Update this documentation

## Questions?

If something isn't clear or you encounter issues:
1. Check `TESTING.md` for validation procedures
2. Review template examples in `project-templates/`
3. Run `scripts/test-lsp-inheritance.sh` for automated diagnostics
