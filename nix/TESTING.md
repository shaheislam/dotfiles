# LSP Inheritance Testing & Validation Guide

Comprehensive step-by-step procedures to test and validate that LSP inheritance works correctly across all three scenarios.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Test Scenario 1: Project A with Custom LSP](#test-scenario-1-project-a-with-custom-lsp)
- [Test Scenario 2: Project B with Different LSP](#test-scenario-2-project-b-with-different-lsp)
- [Test Scenario 3: Global LSP Fallback](#test-scenario-3-global-lsp-fallback)
- [Cross-Scenario Validation](#cross-scenario-validation)
- [Neovim Validation](#neovim-validation)
- [Automated Testing](#automated-testing)
- [Troubleshooting](#troubleshooting)

## Overview

This guide walks through validating the **three-tier LSP inheritance system**:

1. **Project A**: Custom LSP version (e.g., `gopls` v0.15 stable)
2. **Project B**: Different custom LSP version (e.g., `gopls` v0.16 unstable)
3. **Random Directory**: Global LSP fallback (no project-specific override)

### Success Criteria

✅ Each project uses its specified LSP version
✅ Projects are isolated (no cross-contamination)
✅ Global fallback works in directories without flakes
✅ Neovim correctly detects and uses each LSP
✅ Switching between directories works seamlessly

### Automated vs Manual Testing

**Important**: This guide includes both automated and manual testing procedures.

**Automated Testing** (`scripts/test-lsp-inheritance.sh`):
- ✅ Fast verification of LSP inheritance structure
- ✅ Tests flake.nix setup and Nix environment activation
- ✅ Uses `nix develop` directly to verify environment
- ⚠️ Does not test real direnv workflow (that's manual testing)

**Manual Testing** (this guide):
- ✅ **Most authoritative** - tests actual user workflow
- ✅ Tests direnv automatic activation when you `cd` into directories
- ✅ Tests Neovim LSP detection in real usage
- ✅ Recommended for verifying everything works end-to-end

**Recommendation**: Run automated test first for quick validation, then follow manual procedures for comprehensive verification.

## Prerequisites

Before starting, ensure you have:

```bash
# 1. direnv installed and hooked into shell
command -v direnv
# Expected: /nix/store/.../direnv or /usr/local/bin/direnv

# 2. Global LSPs available
ls ~/.nix-profile/bin/gopls
# Expected: /Users/shahe/.nix-profile/bin/gopls exists

# 3. Neovim with LSP config
nvim --version | head -1
# Expected: NVIM v0.9.0+ (LSP built-in)

# 4. Nix flakes enabled
nix --version
# Expected: nix (Nix) 2.18.0+
```

If any prerequisite is missing, see [Troubleshooting](#troubleshooting).

---

## Test Scenario 1: Project A with Custom LSP

### Goal
Create Project A that uses **gopls v0.15 (stable)** via Nix flake override.

### Step 1: Create Test Project A

```bash
# Create project directory
mkdir -p ~/test-lsp-project-a
cd ~/test-lsp-project-a

# Initialize Git (required for direnv)
git init

# Create simple Go file for testing
cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Project A - Testing LSP inheritance")
}
EOF
```

### Step 2: Create flake.nix with Stable gopls

```bash
cat > flake.nix << 'EOF'
{
  description = "Test Project A - gopls v0.15 (stable)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "aarch64-darwin";  # Change to x86_64-darwin or x86_64-linux if needed
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go
          gopls  # Stable version from nixos-24.05
        ];

        shellHook = ''
          echo "🔄 Project A Environment Active"
          echo "   Go: $(go version)"
          echo "   gopls: $(gopls version 2>&1 | head -1)"
          echo "   LSP Path: $(which gopls)"
        '';

        NIX_LSP_ENABLED = "true";
      };
    };
}
EOF
```

### Step 3: Create .envrc

```bash
echo "use flake" > .envrc

# Allow direnv (required first time)
direnv allow
```

### Step 4: Validate Project A Environment

```bash
# After direnv loads, you should see the shellHook output:
# 🔄 Project A Environment Active
#    Go: go version go1.21.x ...
#    gopls: gopls v0.15.3
#    LSP Path: /nix/store/.../gopls

# Manually verify environment
echo $NIX_LSP_ENABLED
# Expected: true

echo $IN_NIX_SHELL
# Expected: impure (or similar)

which gopls
# Expected: /nix/store/...-gopls-0.15.3/bin/gopls

gopls version
# Expected: v0.15.3 (or similar stable version)

echo $PATH | tr ':' '\n' | head -5
# Expected: /nix/store/.../bin should be FIRST
```

### Step 5: Test in Neovim

```bash
nvim main.go

# In Neovim, check LSP status
:LspInfo
# Expected: gopls attached with /nix/store/.../gopls path

# Check environment detection
:lua print(vim.env.NIX_LSP_ENABLED)
# Expected: true

:lua print(vim.env.IN_NIX_SHELL)
# Expected: impure

# Test LSP functionality
# - Hover over "fmt" (should show documentation)
# - Go to definition on "Println" (should jump to source)
# - Save file (should auto-format if configured)
```

### ✅ Success Criteria for Project A

- [x] `gopls version` shows v0.15.x (stable)
- [x] `which gopls` shows `/nix/store/` path
- [x] `NIX_LSP_ENABLED=true`
- [x] Neovim `:LspInfo` shows gopls attached
- [x] LSP features work (hover, go-to-def, formatting)

---

## Test Scenario 2: Project B with Different LSP

### Goal
Create Project B that uses **gopls v0.16+ (unstable)** to verify isolation.

### Step 1: Create Test Project B

```bash
# Create separate project directory
mkdir -p ~/test-lsp-project-b
cd ~/test-lsp-project-b

# Initialize Git
git init

# Create Go file
cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Project B - Testing different gopls version")
}
EOF
```

### Step 2: Create flake.nix with Unstable gopls

```bash
cat > flake.nix << 'EOF'
{
  description = "Test Project B - gopls v0.16+ (unstable)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "aarch64-darwin";  # Change if needed
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.go
          pkgs-unstable.gopls  # Latest version from unstable
        ];

        shellHook = ''
          echo "🚀 Project B Environment Active"
          echo "   Go: $(go version)"
          echo "   gopls: $(gopls version 2>&1 | head -1)"
          echo "   LSP Path: $(which gopls)"
        '';

        NIX_LSP_ENABLED = "true";
      };
    };
}
EOF
```

### Step 3: Create .envrc and Load

```bash
echo "use flake" > .envrc
direnv allow
```

### Step 4: Validate Project B Environment

```bash
# Check shellHook output shows different version:
# 🚀 Project B Environment Active
#    gopls: v0.16.0+

# Verify environment
which gopls
# Expected: /nix/store/...-gopls-0.16.0/bin/gopls (DIFFERENT from Project A)

gopls version
# Expected: v0.16.0+ (unstable version, DIFFERENT from Project A)

echo $NIX_LSP_ENABLED
# Expected: true (same as Project A)
```

### Step 5: Compare Project A vs Project B

```bash
# Switch to Project A
cd ~/test-lsp-project-a
gopls version
# Expected: v0.15.3

# Switch to Project B
cd ~/test-lsp-project-b
gopls version
# Expected: v0.16.0+

# CRITICAL: Versions should be DIFFERENT
```

### ✅ Success Criteria for Project B

- [x] `gopls version` shows v0.16.x+ (unstable, DIFFERENT from A)
- [x] `which gopls` shows `/nix/store/` path (DIFFERENT from A)
- [x] Switching directories changes `gopls` version automatically
- [x] Neovim correctly uses Project B's gopls when editing in Project B

---

## Test Scenario 3: Global LSP Fallback

### Goal
Verify that directories **without** flake.nix use the global LSP fallback.

### Step 1: Navigate to Random Directory

```bash
# Use any directory without flake.nix (e.g., Downloads, Desktop, ~)
cd ~/Downloads

# Or create a test directory
mkdir -p ~/test-no-flake
cd ~/test-no-flake

# Create simple Go file
cat > test.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Testing global LSP fallback")
}
EOF
```

### Step 2: Validate Global Environment

```bash
# Check environment variables
echo $NIX_LSP_ENABLED
# Expected: (empty) - No project-specific environment

echo $IN_NIX_SHELL
# Expected: (empty) - Not in Nix shell

# Check gopls location
which gopls
# Expected: /Users/shahe/.nix-profile/bin/gopls (GLOBAL path, not /nix/store/)

# Check version
gopls version
# Expected: Global version (whatever is in ~/.nix-profile)

# Check PATH
echo $PATH | tr ':' '\n' | head -5
# Expected: ~/.nix-profile/bin should be early in PATH
```

### Step 3: Test in Neovim

```bash
nvim test.go

# Check LSP status
:LspInfo
# Expected: gopls attached with ~/.nix-profile/bin/gopls path

# Check environment
:lua print(vim.env.NIX_LSP_ENABLED or "nil")
# Expected: nil

:lua print(vim.env.IN_NIX_SHELL or "nil")
# Expected: nil

# LSP should still work using global version
```

### ✅ Success Criteria for Global Fallback

- [x] `echo $NIX_LSP_ENABLED` is empty
- [x] `which gopls` shows `~/.nix-profile/bin/gopls`
- [x] No `/nix/store/` path in `which gopls` output
- [x] Neovim LSP works using global gopls
- [x] LSP features still functional (hover, completion, etc.)

---

## Cross-Scenario Validation

### Test: Rapid Directory Switching

Verify that switching directories correctly loads/unloads environments:

```bash
# 1. Start in global environment
cd ~
echo "Global: $(which gopls)"
# Expected: ~/.nix-profile/bin/gopls

# 2. Enter Project A
cd ~/test-lsp-project-a
echo "Project A: $(gopls version | head -1)"
# Expected: v0.15.3

# 3. Enter Project B
cd ~/test-lsp-project-b
echo "Project B: $(gopls version | head -1)"
# Expected: v0.16.0+

# 4. Return to global
cd ~/Downloads
echo "Global: $(which gopls)"
# Expected: ~/.nix-profile/bin/gopls

# 5. Verify isolation
cd ~/test-lsp-project-a
gopls version
# Expected: Still v0.15.3 (not contaminated by Project B)
```

### Test: Concurrent Neovim Sessions

Test that multiple Neovim instances use correct LSPs:

```bash
# Terminal 1: Open Project A
cd ~/test-lsp-project-a
nvim main.go
# :lua print(vim.lsp.get_clients()[1].config.cmd[1])
# Expected: /nix/store/.../gopls-0.15.3/bin/gopls

# Terminal 2: Open Project B (simultaneously)
cd ~/test-lsp-project-b
nvim main.go
# :lua print(vim.lsp.get_clients()[1].config.cmd[1])
# Expected: /nix/store/.../gopls-0.16.0/bin/gopls (DIFFERENT)

# Both should work independently without interference
```

---

## Neovim Validation

### Check LSP Client Configuration

```vim
" In any project, open Neovim and run:

" 1. Show attached LSP clients
:LspInfo
" Look for:
" - Client: gopls (attached)
" - Command: /nix/store/.../gopls or ~/.nix-profile/bin/gopls

" 2. Get client details programmatically
:lua vim.print(vim.lsp.get_clients()[1])
" Check:
" - config.cmd[1] for binary path
" - name for "gopls"

" 3. Check environment detection
:lua print("NIX_LSP_ENABLED: " .. (vim.env.NIX_LSP_ENABLED or "not set"))
:lua print("IN_NIX_SHELL: " .. (vim.env.IN_NIX_SHELL or "not set"))

" 4. Test LSP functionality
" - K (hover) - should show documentation
" - gd (go to definition) - should jump to definition
" - <leader>ca (code action) - should show available actions
```

### Verify LSP Source Detection

Check the detection logic in Neovim config:

```bash
# View the LSP configuration
cat ~/.config/nvim/lua/plugins/lsp.lua | grep -A 10 "IN_NIX_SHELL"

# Should see logic like:
# local in_nix_shell = os.getenv("IN_NIX_SHELL") ~= nil
# local nix_lsp_enabled = os.getenv("NIX_LSP_ENABLED") == "true"
```

---

## Automated Testing

### Run Automated Test Script

```bash
# Run the comprehensive test suite
~/dotfiles/scripts/test-lsp-inheritance.sh

# Expected output:
# === LSP Inheritance Test Suite ===
#
# Test 1: Global Baseline
#   ✅ Global env active
#   ✅ gopls available at ~/.nix-profile/bin/gopls
#
# Test 2: Project A (Stable gopls)
#   ✅ Project env active
#   ✅ gopls version v0.15.3
#   ✅ Using /nix/store/.../gopls
#
# Test 3: Project B (Unstable gopls)
#   ✅ Project env active
#   ✅ gopls version v0.16.0
#   ✅ Using /nix/store/.../gopls (different from A)
#
# Test 4: Isolation Test
#   ✅ Project env unloaded
#   ✅ Global env restored
#
# ✅ All tests passed!
```

### Manual Validation Checklist

Use this checklist to manually verify all functionality:

```
□ Global LSP is available in ~/.nix-profile/bin/
□ Project A activates when entering directory
□ Project A uses correct gopls version
□ Project B activates when entering directory
□ Project B uses DIFFERENT gopls version from A
□ Random directory uses global LSP
□ Switching directories updates environment correctly
□ Neovim detects project-specific LSP in Project A
□ Neovim detects project-specific LSP in Project B
□ Neovim detects global LSP in random directory
□ LSP features work in all three scenarios
□ No cross-contamination between projects
```

---

## Troubleshooting

### Issue: direnv not loading automatically

**Symptoms:**
- No shellHook output when entering directory
- `NIX_LSP_ENABLED` is empty in project directory

**Solution:**
```bash
# Check direnv is hooked into shell
echo $DIRENV_DIR
# Should show current directory when in project

# Manually trigger direnv
direnv allow
direnv reload

# Check shell hook
eval "$(direnv hook bash)"  # or zsh/fish
```

### Issue: gopls not found even in global

**Symptoms:**
- `which gopls` returns nothing
- `command not found: gopls`

**Solution:**
```bash
# Install globally via Nix
nix-env -iA nixpkgs.gopls

# Or via home-manager
# Edit ~/.config/home-manager/home.nix
# Add gopls to packages list, then:
home-manager switch

# Verify installation
ls ~/.nix-profile/bin/gopls
```

### Issue: Project uses global instead of project-specific LSP

**Symptoms:**
- `which gopls` shows `~/.nix-profile/bin/gopls` even in project
- `gopls version` shows global version in project directory

**Solution:**
```bash
# Check direnv is active
echo $NIX_LSP_ENABLED
# If empty, direnv not loaded

# Check PATH order
echo $PATH | tr ':' '\n' | head -3
# /nix/store/.../bin should be BEFORE ~/.nix-profile/bin

# Reload direnv
direnv allow
direnv reload

# If still not working, check flake.nix syntax
nix flake check
```

### Issue: Different projects show same gopls version

**Symptoms:**
- Both Project A and Project B show same version
- `gopls version` identical in both directories

**Solution:**
```bash
# Verify flake.nix files are different
cd ~/test-lsp-project-a
cat flake.nix | grep nixpkgs
# Should show stable channel

cd ~/test-lsp-project-b
cat flake.nix | grep nixpkgs
# Should show unstable channel

# Update flake locks
cd ~/test-lsp-project-a && nix flake update
cd ~/test-lsp-project-b && nix flake update

# Reload direnv in both
cd ~/test-lsp-project-a && direnv reload
cd ~/test-lsp-project-b && direnv reload
```

### Issue: Neovim uses wrong LSP

**Symptoms:**
- `:LspInfo` shows wrong gopls path
- Neovim using global LSP in project directory

**Solution:**
```bash
# Restart Neovim after direnv changes
# (Neovim inherits environment at startup)

# Check Neovim sees environment
nvim -c 'lua print(vim.env.NIX_LSP_ENABLED)' -c 'q'
# Should print "true"

# Check Neovim LSP config
nvim ~/.config/nvim/lua/plugins/lsp.lua
# Verify detection logic is present
```

### Issue: Environment not unloading when leaving project

**Symptoms:**
- `NIX_LSP_ENABLED` still set after leaving project directory
- Global directory shows project LSP path

**Solution:**
```bash
# Check direnv is properly configured
cat ~/.config/direnv/direnvrc
# Should have proper unload hooks

# Manually unload
cd ~/Downloads
direnv reload
unset NIX_LSP_ENABLED IN_NIX_SHELL

# Verify PATH is clean
echo $PATH | grep nix/store
# Should not show project-specific store paths
```

---

## Summary

After completing all tests, you should have verified:

✅ **Three distinct environments** work correctly:
  - Project A with custom LSP version
  - Project B with different custom LSP version
  - Global fallback for directories without flakes

✅ **Isolation** between projects:
  - Projects don't interfere with each other
  - Switching directories updates environment

✅ **Neovim integration** works:
  - Detects project-specific LSPs
  - Falls back to global LSPs
  - LSP features functional in all scenarios

✅ **Automated validation** confirms:
  - All scenarios pass automated tests
  - Environment variables set correctly
  - PATH precedence working as expected

For more information, see:
- [README.md](./README.md) - Architecture overview
- [QUICK_START.md](./QUICK_START.md) - Quick reference
- [project-templates/](./project-templates/) - Template examples
