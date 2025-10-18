# How LSP Overrides Work - Complete Explanation

## Table of Contents
1. [The Core Concept](#the-core-concept)
2. [How PATH Resolution Works](#how-path-resolution-works)
3. [The Override Mechanism](#the-override-mechanism)
4. [Step-by-Step Example](#step-by-step-example)
5. [Creating Your Own Overrides](#creating-your-own-overrides)
6. [Troubleshooting](#troubleshooting)
7. [Quick Reference](#quick-reference)

## The Core Concept

The hybrid approach uses **PATH precedence** to allow project-specific LSP versions to override global ones. Here's the simple version:

1. **Global LSPs** are installed to `~/.nix-profile/bin/` (always available)
2. **Project LSPs** are added to PATH *before* global ones (when in project)
3. **First match wins** - Neovim uses the first LSP it finds in PATH

## How PATH Resolution Works

When you type a command (or Neovim starts an LSP), the system searches PATH directories in order:

```
PATH = /dir1:/dir2:/dir3:/dir4
       ↑ Checked first
                          ↑ Checked last
```

### Without Project Override (Global Baseline)
```
Your PATH looks like:
/Users/you/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin

When Neovim starts gopls:
1. Check /Users/you/.nix-profile/bin/gopls ✓ FOUND (global version 0.15.0)
2. (stops searching - first match wins)

Result: Uses global gopls 0.15.0
```

### With Project Override (direnv Active)
```
Your PATH looks like:
/nix/store/xyz789-gopls-0.16.0/bin:/Users/you/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin
↑ Project's gopls added FIRST

When Neovim starts gopls:
1. Check /nix/store/xyz789-gopls-0.16.0/bin/gopls ✓ FOUND (project version 0.16.0)
2. (stops searching - first match wins)

Result: Uses project's gopls 0.16.0
```

## The Override Mechanism

### Visual Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     PATH Resolution Order                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Normal Shell (no project):                                  │
│  ┌──────────────────┐                                        │
│  │ ~/.nix-profile   │ ← Global LSPs (basedpyright, gopls)   │
│  │ /opt/homebrew    │ ← Homebrew packages                   │
│  │ /usr/local       │ ← System tools                        │
│  │ /usr/bin         │ ← macOS utilities                     │
│  └──────────────────┘                                        │
│                                                               │
│  Inside Project (with .envrc + flake.nix):                   │
│  ┌──────────────────┐                                        │
│  │ /nix/store/abc.. │ ← PROJECT LSPs (pyright override)     │
│  │ ~/.nix-profile   │ ← Global LSPs (fallback)              │
│  │ /opt/homebrew    │ ← Homebrew packages                   │
│  │ /usr/local       │ ← System tools                        │
│  │ /usr/bin         │ ← macOS utilities                     │
│  └──────────────────┘                                        │
│                                                               │
│  🎯 First match wins!                                        │
└─────────────────────────────────────────────────────────────┘
```

### How direnv Makes This Work

1. **You enter a directory** with `.envrc` file
2. **direnv reads** `.envrc` which says `use flake`
3. **direnv runs** the flake.nix to build environment
4. **direnv modifies** your PATH by prepending project paths
5. **Your shell** now has project tools available first

## Step-by-Step Example

Let's create a Python project that uses `pyright` instead of the global `basedpyright`:

### Step 1: Check Current State
```bash
# See what Python LSP you have globally
$ which basedpyright-langserver
/Users/you/.nix-profile/bin/basedpyright-langserver

$ basedpyright-langserver --version
basedpyright 1.18.0
```

### Step 2: Create Project Directory
```bash
$ mkdir ~/my-python-project
$ cd ~/my-python-project
```

### Step 3: Create flake.nix
```nix
# flake.nix
{
  description = "Python project using pyright instead of basedpyright";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Override: Use pyright instead of basedpyright
            nodePackages.pyright

            # Keep using global ruff-lsp
            # (not specified here, so falls back to global)

            # Add project-specific formatter
            python311Packages.black
          ];

          shellHook = ''
            echo "🐍 Project environment active!"
            echo "Using pyright (not basedpyright)"
            which pyright-langserver
          '';
        };
      });
}
```

### Step 4: Create .envrc
```bash
$ echo "use flake" > .envrc
```

### Step 5: Allow direnv
```bash
$ direnv allow
# direnv builds the environment...
🐍 Project environment active!
Using pyright (not basedpyright)
/nix/store/def456-pyright/bin/pyright-langserver
```

### Step 6: Verify Override
```bash
# Inside project directory:
$ which pyright-langserver
/nix/store/def456-pyright/bin/pyright-langserver  # ← Project version

$ which basedpyright-langserver
/Users/you/.nix-profile/bin/basedpyright-langserver  # ← Global still exists

# But Neovim will use pyright because it's first in PATH:
$ echo $PATH | tr ':' '\n' | head -2
/nix/store/def456-pyright/bin      # ← Project paths FIRST
/Users/you/.nix-profile/bin        # ← Global paths second
```

### Step 7: Test in Neovim
```bash
$ nvim test.py

# Inside Neovim, check which LSP is active:
:LspInfo
# Shows: pyright (not basedpyright)
```

### Step 8: Leave Directory
```bash
$ cd ..
# direnv: unloading
# Project environment deactivated

$ which pyright-langserver
# No output - pyright not available globally

$ which basedpyright-langserver
/Users/you/.nix-profile/bin/basedpyright-langserver  # ← Back to global
```

## Creating Your Own Overrides

### Method 1: Use a Template (Easiest)
```bash
# Copy a template
cp -r ~/dotfiles/nix/project-templates/python-project/* .

# Modify the flake.nix to your needs
nvim flake.nix

# Activate
echo "use flake" > .envrc
direnv allow
```

### Method 2: Simple .envrc (Use Global + Extras)
```bash
# .envrc - Just add extra tools, keep all globals
use flake ~/dotfiles/nix/global

# This gives you all global tools plus anything extra defined
# in ~/dotfiles/nix/global
```

### Method 3: Custom flake.nix (Full Control)
```nix
# Create your own flake.nix with exactly what you want
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-darwin;
    in {
      devShells.x86_64-darwin.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Your specific tools here
          gopls  # Latest gopls from unstable
          # Don't specify golangci-lint = uses global version
        ];
      };
    };
}
```

## Troubleshooting

### How to Check Which LSP Is Active

#### 1. In Shell
```bash
# See which version would be used
$ which gopls
/nix/store/abc123.../bin/gopls  # Project version
# or
/Users/you/.nix-profile/bin/gopls  # Global version

# Check version
$ gopls version
```

#### 2. In Neovim
```vim
:LspInfo                 " Shows active LSP servers
:!which gopls           " Check which gopls Neovim would use
:lua =vim.lsp.get_active_clients()[1].config.cmd  " See exact command
```

#### 3. Check PATH Order
```bash
# See PATH directories in order
$ echo $PATH | tr ':' '\n' | head -10

# See all locations of a command
$ type -a gopls
gopls is /nix/store/abc.../bin/gopls      # Project (would be used)
gopls is /Users/you/.nix-profile/bin/gopls # Global (fallback)
```

### Common Issues

#### Issue: "LSP not starting"
```bash
# Check if LSP is installed
$ which basedpyright-langserver

# If not found, install globally:
$ ./scripts/install-lsps-global.sh

# Or add to your project's flake.nix
```

#### Issue: "Wrong version being used"
```bash
# Check PATH order
$ echo $PATH | tr ':' '\n' | grep -E "(nix|profile)"

# Make sure direnv is active
$ direnv status

# Re-allow direnv if needed
$ direnv allow
```

#### Issue: "direnv not activating"
```bash
# Check for .envrc file
$ ls -la .envrc

# Make sure direnv hook is in your shell
$ grep direnv ~/.config/fish/config.fish  # For Fish
$ grep direnv ~/.zshrc                     # For Zsh

# Add if missing:
$ echo 'eval (direnv hook fish)' >> ~/.config/fish/config.fish
```

#### Issue: "Changes to flake.nix not taking effect"
```bash
# Rebuild the environment
$ direnv reload

# Or leave and re-enter directory
$ cd .. && cd -
```

## Quick Reference

### Commands Cheat Sheet
```bash
# Global LSP Management
./scripts/install-lsps-global.sh    # Install global baseline
./scripts/check-lsp-status.sh       # Check what's installed

# Project Override Setup
echo "use flake" > .envrc          # Create envrc
direnv allow                        # Activate environment
direnv reload                       # Reload after changes
direnv deny                         # Deactivate environment

# Debugging
which <lsp-name>                    # Check which version would be used
echo $PATH | tr ':' '\n'           # See PATH order
direnv status                       # Check if direnv is active
type -a <lsp-name>                  # See all available versions

# In Neovim
:LspInfo                            # Show active LSPs
:checkhealth                        # Check for issues
<leader>nl                          # List available LSPs (custom keymap)
```

### File Structure
```
my-project/
├── .envrc          # Contains: use flake
├── flake.nix       # Defines project-specific tools
├── flake.lock      # Pins exact versions (auto-generated)
└── .direnv/        # Cache directory (git-ignored)
```

### Priority Rules
1. **Project tools** (via direnv + flake.nix) - **Highest Priority**
2. **Global tools** (via nix-env) - **Fallback**
3. **System tools** (via homebrew, etc.) - **Lowest Priority**
4. **Mason tools** - **Not used** (disabled for LSPs)

## Summary

The override mechanism is simple: **PATH order determines priority**.

- **Global baseline** ensures LSPs are always available
- **direnv** modifies PATH when you enter a project
- **Project paths** come before global paths
- **First match wins** when looking for an LSP

This gives you the best of both worlds:
- ✅ LSPs always work (global baseline)
- ✅ Projects can use specific versions (overrides)
- ✅ No manual switching required (automatic via direnv)
- ✅ Multiple projects can use different versions simultaneously