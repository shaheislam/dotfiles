# Claude Code LSP Integration

> Native Language Server Protocol integration for Claude Code, providing real-time
> code intelligence without IDE dependency.

## Overview

Claude Code (2.0.30+) supports LSP servers as a plugin component. This gives Claude
access to the same code intelligence that IDEs provide:

- **Instant diagnostics**: Errors and warnings surfaced after each edit
- **Code navigation**: `goToDefinition`, `findReferences`, `hover`
- **Symbol search**: `documentSymbol`, `workspaceSymbol`

LSP integration operates entirely in the terminal — no VS Code or editor required.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│ Claude Code                                          │
│  ├── LSP Tool (5 operations)                         │
│  └── Auto-diagnostics (after Edit/Write)             │
├──────────────────────────────────────────────────────┤
│ LSP Plugins (.lsp.json)                              │
│  └── boostvolt/claude-code-lsps marketplace          │
│      ├── pyright (Python)                            │
│      ├── typescript-language-server (TS/JS)           │
│      ├── gopls (Go)                                  │
│      ├── rust-analyzer (Rust)                        │
│      ├── bash-language-server (Bash/Shell)            │
│      ├── yaml-language-server (YAML)                 │
│      ├── terraform-ls (Terraform)                    │
│      ├── lua-language-server (Lua)                   │
│      └── nil (Nix)                                   │
├──────────────────────────────────────────────────────┤
│ LSP Binaries (must be in PATH)                       │
│  ├── Nix global devShell (nix/global/)  ← primary    │
│  ├── Homebrew                           ← fallback   │
│  └── Project Nix flake (direnv)         ← override   │
└──────────────────────────────────────────────────────┘
```

### Relationship to Nix LSP System

The existing three-tier Nix LSP system (`nix/README.md`) manages LSP binaries for
**Neovim**. Claude Code's LSP plugins reuse those same binaries but configure their
own LSP connections independently:

| Aspect | Neovim (existing) | Claude Code (new) |
|--------|-------------------|-------------------|
| Config | `~/neovim/lua/plugins/lsp.lua` | Plugin `.lsp.json` files |
| Binary source | Nix devShell / PATH | Same — Nix devShell / PATH |
| Management | LazyVim / Mason | `claude plugin` CLI |
| Diagnostics | In-editor gutter | Auto-injected after edits |
| Navigation | `:lua vim.lsp.*` | LSP tool in Claude Code |

Both systems share the same LSP binaries — no duplication needed.

## Setup

### Automatic (via setup.sh)

The setup script handles everything:

```bash
./scripts/setup.sh
```

This:
1. Adds the `boostvolt/claude-code-lsps` marketplace
2. Installs 9 LSP plugins
3. LSP binaries come from Nix global devShell (already installed)

### Manual Installation

```bash
# Add marketplace
claude plugin marketplace add boostvolt/claude-code-lsps

# Install individual plugins
claude plugin install pyright@claude-code-lsps
claude plugin install typescript@claude-code-lsps
claude plugin install gopls@claude-code-lsps
# ... etc

# Restart Claude Code to activate
```

### Verify

```bash
# Fish function for status
cc-lsp status    # Show all LSP plugins and binary availability
cc-lsp doctor    # Health check
cc-lsp install   # (Re)install all plugins
```

## Installed LSP Plugins

| Plugin | Binary | Language | Nix Package |
|--------|--------|----------|-------------|
| `pyright` | `pyright-langserver` | Python | `basedpyright` (unstable, via `scripts/bin/pyright-langserver` fallback wrapper) |
| `typescript` | `typescript-language-server` | TypeScript/JS | `nodePackages.typescript-language-server` |
| `gopls` | `gopls` | Go | `gopls` |
| `rust-analyzer` | `rust-analyzer` | Rust | `rust-analyzer` |
| `bash-lsp` | `bash-language-server` | Bash/Shell | `nodePackages.bash-language-server` |
| `yaml-lsp` | `yaml-language-server` | YAML | `yaml-language-server` |
| `terraform` | `terraform-ls` | Terraform | `terraform-ls` |
| `lua-lsp` | `lua-language-server` | Lua | `emmylua-ls` (unstable) |
| `nix-lsp` | `nil` | Nix | `nil` |

## SessionStart Hook

A lightweight `lsp-status.sh` hook runs at SessionStart to inject available LSP
servers into Claude's context. This ensures Claude knows to use the LSP tool
for code navigation instead of grep-based searching.

For Python, this repo exposes `pyright-langserver` through `scripts/bin/pyright-langserver`.
If the real `pyright-langserver` is not installed, the wrapper falls back to
`basedpyright-langserver` so Claude/OpenCode still see Python LSP support on the
standard Nix setup.

**Output example**: `LSP servers active: Bash/Shell Go Nix Python Rust TypeScript/JavaScript. Use the LSP tool for code intelligence.`

## LSP Tool Operations

Claude Code exposes 5 LSP operations via a builtin tool:

| Operation | Description | Use Case |
|-----------|-------------|----------|
| `goToDefinition` | Jump to symbol definition | Navigate to function/class source |
| `findReferences` | Find all usages of a symbol | Understand impact of changes |
| `hover` | Get type info and docs | Quick symbol documentation |
| `documentSymbol` | List symbols in a file | Understand file structure |
| `workspaceSymbol` | Search symbols across project | Find functions/classes globally |

## Plugin Configuration Format

Each LSP plugin contains a `.lsp.json` file:

```json
{
  "python": {
    "command": "pyright-langserver",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".py": "python",
      ".pyi": "python"
    }
  }
}
```

### Available Fields

| Field | Required | Description |
|-------|----------|-------------|
| `command` | Yes | LSP binary name (must be in PATH) |
| `extensionToLanguage` | Yes | Maps file extensions to language IDs |
| `args` | No | CLI arguments for the LSP server |
| `transport` | No | `stdio` (default) or `socket` |
| `env` | No | Environment variables for the server |
| `initializationOptions` | No | LSP initialization options |
| `settings` | No | Workspace settings |
| `startupTimeout` | No | Max startup wait (ms) |
| `restartOnCrash` | No | Auto-restart on crash |
| `maxRestarts` | No | Max restart attempts |

## Troubleshooting

### "No LSP server available for file type"

The LSP binary is not in PATH. Check:
```bash
cc-lsp status    # See which binaries are missing
which gopls      # Check specific binary
```

Fix: Enter Nix devShell (`nix develop ~/dotfiles/nix/global/`) or install via Homebrew.

### LSP server not starting

Check the plugin errors tab:
```
/plugin  → Errors tab
```

Common issues:
- Binary not found in PATH
- Binary version incompatible
- Startup timeout (increase `startupTimeout` in `.lsp.json`)

### Diagnostics not appearing

- Ensure the file extension matches the plugin's `extensionToLanguage` mapping
- Restart Claude Code after installing plugins
- Check `claude --debug` for LSP initialization errors

### Stale LSP state

LSP servers are long-running processes. If diagnostics seem wrong:
1. Exit and restart Claude Code
2. The LSP servers will reinitialize on startup

## Adding New Language Support

1. Check if `boostvolt/claude-code-lsps` has a plugin for the language
2. Install it: `claude plugin install <name>@claude-code-lsps`
3. Ensure the LSP binary is in PATH (add to Nix `lsp-versions.nix` if needed)
4. Update `cc-lsp.fish` LSP map
5. Update this documentation
6. Add test in `scripts/test-filter.sh` (lsp group)

## References

- [Claude Code Plugins Reference — LSP Servers](https://code.claude.com/docs/en/plugins-reference)
- [boostvolt/claude-code-lsps](https://github.com/boostvolt/claude-code-lsps) — 22 language LSP plugins
- [Piebald-AI/claude-code-lsps](https://github.com/Piebald-AI/claude-code-lsps) — Alternative marketplace
- [Nix LSP Architecture](../nix/README.md) — Three-tier LSP system for Neovim
