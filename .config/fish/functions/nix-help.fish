# nix-help - Nix LSP Inheritance System Reference
function nix-help --description "Show Nix LSP inheritance system help and quick reference"
    set -l help_text "
╭──────────────────────────────────────────────────────────────────────────╮
│                   Nix LSP Inheritance System Guide                       │
╰──────────────────────────────────────────────────────────────────────────╯

QUICK REFERENCE - Most Used Commands:
  nix-help (nh)     Show this comprehensive guide
  lsp-help (lh)     Show LSP-specific operations and config

  Quick Start:      cd ~/my-project && nix flake init -t ~/dotfiles/nix/project-templates#go-project
  Verify:           echo \$NIX_LSP_ENABLED && which gopls
  Test System:      ~/dotfiles/scripts/test-lsp-inheritance.sh

═══════════════════════════════════════════════════════════════════════════
 OVERVIEW: THREE-TIER LSP SYSTEM
═══════════════════════════════════════════════════════════════════════════

The system provides three layers of LSP configuration:

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

WHY THIS MATTERS:
✅ Use global baseline LSPs available everywhere
✅ Override LSP versions per-project using Nix flakes
✅ Isolate projects from each other (no conflicts)
✅ Pin specific versions for legacy compatibility
✅ Mix and match different LSP stacks per project

═══════════════════════════════════════════════════════════════════════════
 QUICK START
═══════════════════════════════════════════════════════════════════════════

USING A TEMPLATE:
  cd ~/my-project
  nix flake init -t ~/dotfiles/nix/project-templates#TEMPLATE_NAME
  direnv allow
  which gopls          # Should be /nix/store/.../gopls
  echo \$NIX_LSP_ENABLED  # Should be \"true\"
  nvim main.go         # LSP should attach automatically

AVAILABLE TEMPLATES:
  go-project          gopls, golangci-lint-langserver
  python-project      basedpyright (or pyright), ruff-lsp
  nodejs-project      typescript-language-server, eslint
  terraform-project   terraform-ls

═══════════════════════════════════════════════════════════════════════════
 COMMON COMMANDS
═══════════════════════════════════════════════════════════════════════════

CHECK ENVIRONMENT:
  echo \$NIX_LSP_ENABLED        # \"true\" = project, empty = global
  which gopls                  # /nix/store/... = project, ~/.nix-profile/... = global
  gopls version                # Check LSP version
  echo \$PATH | tr ':' '\\n' | head -3   # Project should be first

DIRENV OPERATIONS:
  direnv allow                 # Allow new .envrc (required first time)
  direnv reload                # Reload after flake.nix changes
  direnv status                # Check direnv status
  direnv deny                  # Temporarily disable direnv

NIX FLAKE OPERATIONS:
  nix flake update             # Update flake dependencies
  nix flake check              # Check flake syntax
  nix flake show               # Show flake info
  nix develop                  # Enter development shell manually (without direnv)

═══════════════════════════════════════════════════════════════════════════
 INHERITANCE PATTERNS
═══════════════════════════════════════════════════════════════════════════

PATTERN 1: DEFAULT INHERITANCE (Recommended)
Use when: You want everything from global + a few extras

  {
    inputs.dotfiles.url = \"path:/Users/shaheislam/dotfiles/nix/global\";

    devShells.default = pkgs.mkShell {
      inputsFrom = [ dotfiles.outputs.devShells.\${system}.default ];
      buildInputs = [ pkgs.postgresql ];  # Add just PostgreSQL
    };
  }

PATTERN 2: SELECTIVE OVERRIDE
Use when: You want to replace ONE specific LSP version

  {
    inputs.nixpkgs-unstable.url = \"github:NixOS/nixpkgs/nixos-unstable\";

    devShells.default = pkgs.mkShell {
      buildInputs = [
        pkgs-unstable.gopls  # Override just gopls with unstable
        # All other LSPs come from global (via PATH)
      ];
    };
  }

PATTERN 3: COMPLETE OVERRIDE
Use when: Project needs a completely different LSP stack

  {
    devShells.default = pkgs.mkShell {
      buildInputs = [
        pkgs.nodePackages.pyright  # Use pyright instead of basedpyright
        pkgs.ruff-lsp
        # No inheritance - completely custom stack
      ];
    };
  }

PATTERN 4: VERSION PINNING (Legacy Projects)
Use when: Project requires specific old version

  {
    inputs.nixpkgs-legacy.url = \"github:NixOS/nixpkgs/abc123\";

    devShells.default = pkgs.mkShell {
      buildInputs = [
        nixpkgs-legacy.legacyPackages.\${system}.gopls  # Pinned version
      ];
    };
  }

═══════════════════════════════════════════════════════════════════════════
 VALIDATION & TESTING
═══════════════════════════════════════════════════════════════════════════

AUTOMATED TEST:
  ~/dotfiles/scripts/test-lsp-inheritance.sh

QUICK VALIDATION ONE-LINERS:
  # Are projects isolated?
  cd ~/project-a && gopls version && cd ~/project-b && gopls version
  # Should show DIFFERENT versions

  # Does global fallback work?
  cd ~ && echo \$NIX_LSP_ENABLED
  # Should be empty

  # Neovim detects environment?
  nvim -c 'lua print(vim.env.NIX_LSP_ENABLED or \"GLOBAL\")' -c 'q'
  # Should print \"true\" in project, \"GLOBAL\" elsewhere

MANUAL VALIDATION:
  cd ~/my-project && direnv allow
  which gopls              # Should show /nix/store/... path
  echo \$NIX_LSP_ENABLED    # Should be \"true\"

  cd ~
  which gopls              # Should show ~/.nix-profile/bin/gopls
  echo \$NIX_LSP_ENABLED    # Should be empty

═══════════════════════════════════════════════════════════════════════════
 TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

LSP NOT FOUND:
  Problem: gopls: command not found
  Solution:
    ls ~/.nix-profile/bin/gopls        # Check if installed
    home-manager switch                # Rebuild if missing
    nix-env -iA nixpkgs.gopls          # Install globally

WRONG LSP VERSION:
  Problem: Using global instead of project-specific
  Solution:
    direnv status                      # Check direnv is active
    direnv allow                       # If not allowed
    echo \$PATH | tr ':' '\\n' | head -5  # Project /nix/store should be FIRST

ENVIRONMENT VARIABLES NOT SET:
  Problem: NIX_LSP_ENABLED is empty
  Solution:
    cat flake.nix | grep NIX_LSP_ENABLED    # Should have: NIX_LSP_ENABLED = \"true\";
    direnv reload                           # Reload direnv

PROJECT ISOLATION NOT WORKING:
  Problem: Project A's LSP leaks into Project B
  Solution:
    ls ~/project-a/flake.nix           # Should exist
    ls ~/project-b/flake.nix           # Should exist
    # Direnv should unload when leaving:
    cd ~/project-a && echo \$NIX_LSP_ENABLED  # \"true\"
    cd ~ && echo \$NIX_LSP_ENABLED            # empty
    cd ~/project-b && echo \$NIX_LSP_ENABLED  # \"true\"

═══════════════════════════════════════════════════════════════════════════
 KEY FILES
═══════════════════════════════════════════════════════════════════════════

  ~/dotfiles/nix/README.md              Full architecture guide
  ~/dotfiles/nix/QUICK_START.md         Quick reference card
  ~/dotfiles/nix/TESTING.md             Step-by-step validation
  ~/dotfiles/nix/lsp-versions.nix       LSP version registry
  ~/dotfiles/nix/global/flake.nix       Global baseline environment
  ~/dotfiles/nix/project-templates/     Language-specific templates
  ~/neovim/lua/plugins/lsp.lua          Neovim LSP detection logic

═══════════════════════════════════════════════════════════════════════════
 ENVIRONMENT VARIABLES
═══════════════════════════════════════════════════════════════════════════

  NIX_LSP_ENABLED      Set by project flake.nix, \"true\" = project LSP active
  IN_NIX_SHELL         Set by Nix when in 'nix develop' shell
  DIRENV_DIR           Current direnv-managed directory
  PATH                 Project bins first, then global (automatic precedence)

═══════════════════════════════════════════════════════════════════════════
 RELATED DOCUMENTATION
═══════════════════════════════════════════════════════════════════════════

  lsp-help (lh)                              LSP-specific operations
  ~/dotfiles/nix/README.md                   Full architecture guide
  ~/dotfiles/nix/TESTING.md                  Comprehensive validation
  ~/dotfiles/nix/project-templates/README    Template usage guide

═══════════════════════════════════════════════════════════════════════════
"

    # Display help text with bat if available, otherwise use less
    if command -v bat >/dev/null
        echo "$help_text" | bat --language=markdown --style=grid --paging=always
    else
        echo "$help_text" | less -R
    end
end

# Create an abbreviation for convenience
abbr -a nh nix-help
