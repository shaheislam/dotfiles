# Nix LSP Setup Guide - Hybrid Approach

## Quick Start

The **recommended approach** is the hybrid setup that provides global baseline LSPs with the ability to override them per-project:

### Hybrid Setup (Recommended)
```bash
# Set up global LSPs + direnv for project overrides
./scripts/activate-nix-lsps.sh hybrid
# or just:
./scripts/activate-nix-lsps.sh
```

This gives you:
- ✅ **Global baseline LSPs**: Always available, never missing
- ✅ **Project-specific overrides**: Use different versions when needed
- ✅ **PATH precedence**: Project LSPs automatically override global ones

### Alternative Options

#### Option 1: Nix Shell (Per Session)
```bash
# Enter a shell with all LSPs
./scripts/activate-nix-lsps.sh shell
```

#### Option 2: direnv-only (No Global Baseline)
```bash
# Only load LSPs via direnv (must be in project with .envrc)
./scripts/activate-nix-lsps.sh direnv-only
```

## What Changed

Previously, Mason.nvim was managing your LSPs. Now we use the **hybrid approach**:
- ✅ **Mason is disabled** - No auto-installations or version conflicts
- ✅ **Global baseline LSPs** - Always available via nix-env
- ✅ **Project overrides** - Use direnv + flake.nix for specific versions
- ✅ **Formatters are optional** - Uncomment in Nix config when needed
- ✅ **PATH precedence** - Project LSPs automatically override global ones

## Available LSPs

The global Nix profile includes:
- **Go**: gopls, golangci-lint, delve
- **Python**: pyright/basedpyright, ruff-lsp, debugpy
- **Rust**: rust-analyzer
- **TypeScript/JavaScript**: typescript-language-server, eslint, vtsls
- **Terraform**: terraform-ls, tflint
- **Docker**: dockerfile-language-server, docker-compose-language-service
- **YAML**: yaml-language-server, yamllint
- **Ansible**: ansible-language-server
- **Helm**: helm-ls
- **And more**: Lua, Markdown, SQL, Nix, TOML, Java, C/C++

## Check LSP Status in Neovim

- `<leader>nl` - List available LSPs
- `<leader>nf` - List available formatters
- `<leader>ns` - Show active LSP status

## Troubleshooting

### LSPs Not Working?
1. Check if LSP is installed: `which gopls`
2. Check Neovim status: `<leader>nl`
3. Install globally: `./scripts/install-lsps-global.sh`

### Want to Enable Formatters?
Edit `nix/global/default.nix` and uncomment the formatters you need:
```nix
# Change this:
# lspVersions.golang.gofumpt  # Formatter - enable per project

# To this:
lspVersions.golang.gofumpt  # Formatter - enable per project
```

Then rebuild: `./scripts/activate-nix-lsps.sh build`

## Hybrid Approach: How It Works

> **📚 For a detailed explanation with diagrams and examples, see [NIX_LSP_OVERRIDE_EXPLAINED.md](NIX_LSP_OVERRIDE_EXPLAINED.md)**

### 1. Global Baseline (Always Available)
LSPs installed globally via `nix-env` are always in your PATH:
```bash
which gopls  # /Users/you/.nix-profile/bin/gopls
```

### 2. Project Overrides (When Needed)
Create a project-specific environment that overrides global LSPs:

#### Simple Override (.envrc only)
```bash
# In your project directory
echo "use flake ~/dotfiles/nix/global" > .envrc
direnv allow
```

#### Custom Override (with flake.nix)
```bash
# Create custom flake.nix (see examples below)
echo "use flake" > .envrc
direnv allow
```

### 3. PATH Precedence
When you enter a project with direnv:
1. Project LSPs are added to PATH **first**
2. Global LSPs remain as **fallback**
3. Neovim uses the **first match** in PATH

## Project Override Examples

### Python: Use pyright instead of basedpyright
```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodePackages.pyright  # Override basedpyright
            ruff-lsp             # Keep global version
            python311Packages.black  # Add formatter
          ];
        };
      });
}
```

### Go: Test latest gopls
```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # unstable channel
  # ... rest of flake config with latest gopls
}
```

### TypeScript: Use beta TypeScript
```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # ... config with latest typescript-language-server
}
```

Full examples available in `nix/project-templates/`

## Migration from Mason

Your Mason LSPs are still installed but inactive. Once Nix LSPs are working, you can optionally clean up:
```bash
rm -rf ~/.local/share/nvim/mason
```

## Benefits of This Setup

1. **Version Control**: LSP versions are pinned in Nix
2. **Project Isolation**: Different projects can use different LSP versions
3. **No Conflicts**: Mason won't override your Nix packages
4. **Reproducible**: Same LSPs across all machines
5. **Fast**: No downloading/compiling on first use