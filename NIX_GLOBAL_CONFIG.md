# Nix Global Configuration & Inheritance Guide

## Overview

This guide explains the three-tier Nix configuration system that provides:
1. **Global packages** via Home Manager (always available)
2. **Base development profiles** (shared across projects)
3. **Per-project overrides** (specific versions and tools)

## Architecture

```
~
├── .config/home-manager/      # Tier 1: Global user environment
│   ├── home.nix               # Always-available packages
│   └── flake.nix              # Reproducible home config
├── dotfiles/nix/
│   ├── global/                # Tier 2: Base development profile
│   │   ├── default.nix        # Common dev tools
│   │   ├── flake.nix          # Flake wrapper
│   │   └── overlays.nix      # Package customizations
│   └── flake-templates/       # Templates with inheritance
└── work/                      # Tier 3: Project-specific
    ├── flake.nix             # Base for all work projects
    ├── service-a/
    │   └── flake.nix         # Extends work base
    └── service-b/
        └── .envrc            # Just uses work base
```

## Quick Start

### Initial Setup

```bash
# 1. Install Nix and Home Manager (done by setup script)
~/dotfiles/scripts/setup/setup-script.sh

# 2. Activate Home Manager (global packages)
hm-switch  # or: cd ~/.config/home-manager && nix run . -- switch --flake .

# 3. Verify global packages
hm-packages

# 4. Check inheritance status
nix-inheritance
```

### Using in Projects

#### Create a new project with inheritance:
```bash
cd ~/projects/my-app

# Option 1: Use template with inheritance
cp ~/dotfiles/nix/flake-templates/with-inheritance.nix flake.nix

# Option 2: Create minimal flake that extends global
cat > flake.nix << 'EOF'
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    global-env.url = "path:/Users/shaheislam/dotfiles/nix/global";
  };

  outputs = { self, nixpkgs, global-env, ... }:
    let pkgs = nixpkgs.legacyPackages.aarch64-darwin; in {
      devShells.aarch64-darwin.default = pkgs.mkShell {
        inputsFrom = [ global-env.devShells.aarch64-darwin.default ];
        buildInputs = [ /* project-specific packages */ ];
      };
    };
}
EOF

# Enable direnv
echo "use flake" > .envrc
direnv allow
```

## Inheritance Patterns

### Pattern 1: Full Inheritance (Extend)

```nix
# Inherit everything from global/parent and add more
devShells.default = pkgs.mkShell {
  inputsFrom = [ global-env.devShells.${system}.default ];
  buildInputs = with pkgs; [
    # Additional project packages
    nodejs_20
    postgresql_15
  ];
};
```

### Pattern 2: Selective Inheritance

```nix
# Pick specific packages from global
devShells.default = pkgs.mkShell {
  buildInputs =
    # Select specific packages from global
    (with global-env.lib.${system}.packages; [
      golang.stable
      terraform.stable
    ]) ++
    # Add project packages
    (with pkgs; [ kubernetes-helm ]);
};
```

### Pattern 3: Override Specific Packages

```nix
# Filter out packages you want to replace
let
  globalPackages = builtins.filter
    (p: !(builtins.elem (pkgs.lib.getName p) ["python" "gopls"]))
    global-env.devShells.${system}.default.buildInputs;
in
devShells.default = pkgs.mkShell {
  buildInputs = globalPackages ++ [
    pkgs.python39      # Different Python version
    pkgs.gopls_0_14_2  # Specific gopls version
  ];
};
```

### Pattern 4: Complete Isolation

```nix
# Don't inherit anything, define from scratch
devShells.isolated = pkgs.mkShell {
  buildInputs = with pkgs; [
    # Only these packages, no global
    git
    nodejs
    typescript
  ];
};
```

## Real-World Example: ~/work Setup

### Base Configuration (`~/work/flake.nix`)
```nix
# Common tools for all work services
buildInputs = with pkgs; [
  # Standard LSPs
  gopls
  basedpyright
  terraform-ls

  # Common work tools
  vault
  consul
  awscli2
  kubectl
];
```

### Service Extension (`~/work/api-service/flake.nix`)
```nix
{
  inputs.work-base.url = "path:..";

  devShells.default = pkgs.mkShell {
    inputsFrom = [ work-base.devShells.default ];
    buildInputs = [
      # Service-specific additions
      air  # Go live reload
      temporal  # Workflow engine
    ];
  };
}
```

### Direnv Setup (`~/work/.envrc`)
```bash
use flake
export WORK_NIX_BASE="true"  # Mark for children
```

### Child Service (`~/work/api-service/.envrc`)
```bash
source_up  # Inherit parent environment
use flake  # Add local overrides
```

## How It Works with Neovim

When you open a file in Neovim:

1. **Direnv activates** based on current directory
2. **Environment inherits** from parent directories (if configured)
3. **Neovim detects** LSPs in this order:
   - Nix shell (if IN_NIX_SHELL is set)
   - System PATH (includes Home Manager packages)
   - Mason (fallback)

### Dynamic Switching

```bash
cd ~/work/service-a
nvim main.go  # Uses service-a's environment (work + service-a)

cd ~/work
nvim README.md  # Uses work base environment

cd ~/personal/project
nvim test.py  # Uses Home Manager globals + project flake
```

## Home Manager Commands

```bash
# Activation
hm-switch         # Activate Home Manager configuration
hm-update         # Update and switch to latest

# Management
hm-packages       # List installed packages
hm-generations    # Show generations
hm-rollback      # Rollback to previous generation

# Status
nix-inheritance   # Show full inheritance chain
nix-lsps         # List available LSPs
nix-status       # Show Nix environment status
```

## Advantages of This Setup

### Over Mason/asdf/mise:
- **Version Control**: All LSP versions in git
- **Team Consistency**: Exact same versions for everyone
- **Inheritance**: DRY principle, define once
- **Isolation**: No global pollution
- **Reproducibility**: Guaranteed same environment

### Over Pure Per-Project:
- **No Duplication**: Common tools defined once
- **Faster Setup**: Inherit instead of redefine
- **Consistency**: Base standards across projects
- **Flexibility**: Override when needed

## Troubleshooting

### Home Manager not activating
```bash
# Manual activation
cd ~/.config/home-manager
nix run . -- switch --flake .

# Check for errors
nix flake check
```

### Inheritance not working
```bash
# Check flake inputs
nix flake metadata

# Verify parent flake
nix flake show path:/Users/shaheislam/dotfiles/nix/global

# Check direnv
direnv status
```

### LSP not found
```bash
# Check inheritance chain
nix-inheritance

# Verify LSP in environment
which gopls

# Check Neovim detection
:LspInfo  # In Neovim
```

### Performance issues
```bash
# Clean up old generations
nix-collect-garbage -d

# Optimize store
nix-store --optimise

# Update flake inputs
nix flake update
```

## Best Practices

1. **Define globally, override locally**
   - Common tools in Home Manager
   - Project patterns in global/
   - Specific versions in project flakes

2. **Use direnv for automation**
   - `.envrc` with `use flake`
   - `source_up` for inheritance
   - `direnv allow` to activate

3. **Version everything**
   - Commit `flake.nix` and `flake.lock`
   - Pin critical tool versions
   - Document version requirements

4. **Test inheritance**
   - Use `nix-inheritance` to verify
   - Check LSP resolution order
   - Validate in clean environment

5. **Optimize smartly**
   - Don't duplicate packages
   - Use overlays for customization
   - Cache evaluation results

## Migration Path

### From Pure Project Nix:
1. Extract common packages to global/
2. Update project flakes to inherit
3. Remove duplicated packages
4. Test each project

### From Mason/asdf:
1. Set up Home Manager with common tools
2. Create project flakes for specific versions
3. Disable Mason auto-install
4. Gradually migrate projects

### For Teams:
1. Document standard global packages
2. Share global/ configuration
3. Provide project templates
4. Training on inheritance patterns

## Summary

The three-tier system provides:
- **Tier 1 (Home Manager)**: Always-available global tools
- **Tier 2 (Global Profile)**: Shared development base
- **Tier 3 (Projects)**: Specific overrides and additions

This gives you consistency where you want it and flexibility where you need it, all while maintaining reproducibility and version control.