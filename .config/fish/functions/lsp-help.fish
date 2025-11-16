# lsp-help - LSP Operations and Configuration Reference
function lsp-help --description "Show LSP-specific operations, Neovim integration, and language setup"
    set -l help_text "
╭──────────────────────────────────────────────────────────────────────────╮
│                     LSP Operations & Configuration                       │
╰──────────────────────────────────────────────────────────────────────────╯

QUICK REFERENCE - Most Used Commands:
  lsp-help (lh)     Show this LSP operations guide
  nix-help (nh)     Show Nix LSP inheritance system guide

  Check LSP:        which gopls && gopls version
  Neovim LSP:       :LspInfo  :LspRestart  :LspLog
  Test System:      ~/dotfiles/scripts/test-lsp-inheritance.sh

═══════════════════════════════════════════════════════════════════════════
 NEOVIM LSP COMMANDS
═══════════════════════════════════════════════════════════════════════════

CHECKING LSP STATUS:
  :LspInfo                              Show active LSP clients and status
  :lua vim.print(vim.lsp.get_clients()) Show all attached LSP clients
  :lua print(vim.env.NIX_LSP_ENABLED)   Check if project LSP is active
  :lua print(vim.env.IN_NIX_SHELL)      Check if in Nix shell
  :LspLog                               View LSP client logs

LSP OPERATIONS:
  :LspRestart                           Restart LSP server
  :LspStart                             Start LSP server
  :LspStop                              Stop LSP server

DEBUGGING LSP:
  :lua print(vim.lsp.get_clients()[1].config.cmd[1])   Show LSP binary path
  :lua print(vim.inspect(vim.lsp.get_clients()[1]))    Full client config

LSP FEATURES (via LazyVim):
  gd              Go to definition
  gr              Go to references
  gI              Go to implementation
  gy              Go to type definition
  K               Show hover documentation
  gK              Show signature help
  <leader>ca      Code actions
  <leader>cr      Rename symbol
  <leader>cf      Format code

═══════════════════════════════════════════════════════════════════════════
 PER-LANGUAGE LSP SETUP
═══════════════════════════════════════════════════════════════════════════

GO (GOLANG):
  Template:     nix flake init -t ~/dotfiles/nix/project-templates#go-project
  LSPs:         gopls, golangci-lint-langserver
  Check:        which gopls && gopls version
  Config:       ~/neovim/lua/plugins/lsp.lua

  Example flake.nix:
    buildInputs = [
      pkgs.go
      pkgs.gopls
      pkgs.golangci-lint
      pkgs.golangci-lint-langserver
    ];

PYTHON:
  Template:     nix flake init -t ~/dotfiles/nix/project-templates#python-project
  LSPs:         basedpyright (default) OR pyright, ruff-lsp
  Check:        which basedpyright && basedpyright --version
  Config:       ~/neovim/lua/plugins/lsp.lua

  Example flake.nix (basedpyright):
    buildInputs = [
      pkgs.python3
      pkgs.basedpyright
      pkgs.ruff-lsp
    ];

  Example flake.nix (pyright):
    buildInputs = [
      pkgs.python3
      pkgs.nodePackages.pyright
      pkgs.ruff-lsp
    ];

NODE.JS / TYPESCRIPT:
  Template:     nix flake init -t ~/dotfiles/nix/project-templates#nodejs-project
  LSPs:         typescript-language-server, eslint
  Check:        which typescript-language-server
  Config:       ~/neovim/lua/plugins/lsp.lua

  Example flake.nix:
    buildInputs = [
      pkgs.nodejs
      pkgs.nodePackages.typescript-language-server
      pkgs.nodePackages.eslint
    ];

TERRAFORM:
  Template:     nix flake init -t ~/dotfiles/nix/project-templates#terraform-project
  LSPs:         terraform-ls
  Check:        which terraform-ls && terraform-ls --version
  Config:       ~/neovim/lua/plugins/lsp.lua

  Example flake.nix:
    buildInputs = [
      pkgs.terraform
      pkgs.terraform-ls
    ];

═══════════════════════════════════════════════════════════════════════════
 LSP VERSION MANAGEMENT
═══════════════════════════════════════════════════════════════════════════

CHECK CURRENT VERSION:
  gopls version                         Check gopls version
  basedpyright --version                Check basedpyright version
  terraform-ls --version                Check terraform-ls version
  typescript-language-server --version  Check TS LSP version

AVAILABLE VERSIONS (in lsp-versions.nix):
  cat ~/dotfiles/nix/lsp-versions.nix   View all LSP version profiles

OVERRIDE TO UNSTABLE:
  # In project flake.nix, add unstable input:
  inputs.nixpkgs-unstable.url = \"github:NixOS/nixpkgs/nixos-unstable\";

  # Then use unstable package:
  buildInputs = [ pkgs-unstable.gopls ];

PIN SPECIFIC VERSION:
  # Find commit hash for desired version at:
  # https://github.com/NixOS/nixpkgs/commits/master

  inputs.nixpkgs-legacy.url = \"github:NixOS/nixpkgs/abc123def456\";
  buildInputs = [ nixpkgs-legacy.legacyPackages.\${system}.gopls ];

═══════════════════════════════════════════════════════════════════════════
 TESTING LSP INHERITANCE
═══════════════════════════════════════════════════════════════════════════

AUTOMATED TEST SUITE:
  ~/dotfiles/scripts/test-lsp-inheritance.sh

  Tests:
    ✓ Global LSPs installed and accessible
    ✓ Project LSPs override globals correctly
    ✓ PATH precedence (project before global)
    ✓ Environment variables set correctly
    ✓ Projects isolated from each other
    ✓ Neovim detects and uses correct LSPs

MANUAL TESTING:
  # Test 1: Global fallback
  cd ~ && which gopls
  # Expected: ~/.nix-profile/bin/gopls

  # Test 2: Project override
  cd ~/my-project && which gopls
  # Expected: /nix/store/.../gopls

  # Test 3: Isolation
  cd ~/project-a && gopls version    # Version A
  cd ~/project-b && gopls version    # Version B (different)

  # Test 4: Neovim detection
  cd ~/my-project && nvim main.go
  # In Neovim: :lua print(vim.env.NIX_LSP_ENABLED)
  # Expected: \"true\"

═══════════════════════════════════════════════════════════════════════════
 COMMON ISSUES & SOLUTIONS
═══════════════════════════════════════════════════════════════════════════

NEOVIM NOT USING NIX LSP:
  Problem: :LspInfo shows system LSP instead of Nix
  Solution:
    1. Check environment:
       :lua print(vim.env.IN_NIX_SHELL)      # Should be \"true\" or \"impure\"
       :lua print(vim.env.NIX_LSP_ENABLED)   # Should be \"true\"

    2. Verify LSP binary path:
       :lua print(vim.lsp.get_clients()[1].config.cmd[1])
       # Should show /nix/store/... path

    3. Restart Neovim after direnv changes
       direnv allow && direnv reload
       # Then restart Neovim

    4. Check LSP config:
       cat ~/neovim/lua/plugins/lsp.lua | grep -A 10 \"gopls\"

LSP NOT ATTACHING:
  Problem: :LspInfo shows \"0 client(s) attached to this buffer\"
  Solution:
    1. Check LSP is installed:
       which gopls                           # Should return a path

    2. Check Neovim filetype:
       :set filetype?                        # Should match language (e.g., go)

    3. Manually start LSP:
       :LspStart

    4. Check logs:
       :LspLog                               # Look for error messages

WRONG LSP VERSION IN NEOVIM:
  Problem: Using old/wrong version despite project override
  Solution:
    1. Verify direnv loaded:
       echo \$NIX_LSP_ENABLED                 # Should be \"true\"

    2. Check which binary Neovim will use:
       which gopls                           # Should show /nix/store/... path

    3. Restart Neovim (it inherits environment at startup)

    4. Force LSP restart in Neovim:
       :LspRestart

LSP FEATURES NOT WORKING:
  Problem: gd (go to definition) or other LSP features don't work
  Solution:
    1. Check LSP is attached:
       :LspInfo                              # Should show active client

    2. Verify LSP supports feature:
       :lua print(vim.inspect(vim.lsp.get_clients()[1].server_capabilities))

    3. Check for LSP errors:
       :LspLog                               # Look for warnings/errors

    4. Try manual code action:
       :lua vim.lsp.buf.definition()

MULTIPLE LSPs CONFLICTING:
  Problem: Multiple LSPs trying to provide same features
  Solution:
    1. Check which LSPs are active:
       :LspInfo

    2. Disable specific LSP in Neovim config:
       Edit ~/neovim/lua/plugins/lsp.lua

    3. Or stop specific LSP:
       :lua vim.lsp.stop_client(vim.lsp.get_clients()[1].id)

═══════════════════════════════════════════════════════════════════════════
 PROJECT TEMPLATES
═══════════════════════════════════════════════════════════════════════════

TEMPLATE LOCATIONS:
  ~/dotfiles/nix/project-templates/go-project/flake.nix
  ~/dotfiles/nix/project-templates/python-project/flake.nix
  ~/dotfiles/nix/project-templates/nodejs-project/flake.nix
  ~/dotfiles/nix/project-templates/terraform-project/flake.nix

USING TEMPLATES:
  cd ~/my-new-project
  nix flake init -t ~/dotfiles/nix/project-templates#TEMPLATE_NAME
  direnv allow

CUSTOMIZING TEMPLATES:
  1. Copy template to project:
     nix flake init -t ~/dotfiles/nix/project-templates#go-project

  2. Edit flake.nix:
     nvim flake.nix

  3. Add/remove packages in buildInputs:
     buildInputs = [
       pkgs.go
       pkgs.gopls
       pkgs.postgresql  # Add database
     ];

  4. Reload environment:
     direnv reload

═══════════════════════════════════════════════════════════════════════════
 NEOVIM LSP CONFIGURATION
═══════════════════════════════════════════════════════════════════════════

CONFIG LOCATION:
  ~/neovim/lua/plugins/lsp.lua          Main LSP configuration

DETECTION LOGIC:
  The config checks:
    1. Is Nix LSP available? (NIX_LSP_ENABLED env var)
    2. Is command in PATH? (which gopls)
    3. Are we in a Nix shell? (IN_NIX_SHELL env var)

  If in project with flake.nix:
    → Use project-specific LSP from /nix/store

  If in directory without flake.nix:
    → Use global LSP from ~/.nix-profile

MODIFYING LSP SETTINGS:
  Edit: ~/neovim/lua/plugins/lsp.lua

  Example (custom gopls settings):
    gopls = {
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
          },
          staticcheck = true,
        },
      },
    },

═══════════════════════════════════════════════════════════════════════════
 ADDITIONAL RESOURCES
═══════════════════════════════════════════════════════════════════════════

  nix-help (nh)                              Nix inheritance system guide
  ~/dotfiles/nix/README.md                   Architecture documentation
  ~/dotfiles/nix/TESTING.md                  Validation procedures
  ~/dotfiles/nix/project-templates/README    Template usage guide
  ~/dotfiles/scripts/test-lsp-inheritance.sh Automated test suite
  ~/neovim/lua/plugins/lsp.lua               Neovim LSP configuration

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
abbr -a lh lsp-help
