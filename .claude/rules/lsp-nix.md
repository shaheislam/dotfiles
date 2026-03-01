---
paths:
  - "nix/**"
---

# LSP & Nix Configuration

## LSP Management
- Three-tier system: Global baseline → Project override → Neovim detection
- ALWAYS refer to `nix/README.md` for architecture and inheritance patterns
- ALWAYS use Nix flakes for project-specific LSP versions (not Mason.nvim)
- ALWAYS test LSP inheritance with `scripts/test-lsp-inheritance.sh`
- See `nix/README.md`, `nix/TESTING.md`, `nix/QUICK_START.md` for details

## Claude Code LSP Integration
Native LSP servers for Claude Code. Docs: `docs/claude-code-lsp.md`.

**Marketplace**: `boostvolt/claude-code-lsps` (22 languages). Installed via `scripts/setup.sh`.
**Installed**: pyright, typescript, gopls, rust-analyzer, bash-lsp, yaml-lsp, terraform, lua-lsp, nix-lsp.
**LSP binaries**: Reuses Nix global devShell binaries (`nix/global/`). Same binaries serve both Neovim and Claude Code.
**Fish command**: `cc-lsp status|install|doctor`
**Tests**: `scripts/test-filter.sh lsp`
