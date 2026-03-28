# Gemini CLI Rules for Dotfiles

> Project context for Google Gemini CLI. NOT a symlink to CLAUDE.md — these tools have different capabilities and instruction formats.

## Core Rules

### Setup Script Compatibility
- ALWAYS check if `scripts/setup.sh` needs modification when adding new tools
- ALWAYS verify new dependencies are in the Brewfile and setup script
- ALWAYS ensure PATH configs are added to both Fish and Zsh configs

### File Location Constraints
- NEVER create or modify files outside `~/dotfiles` (EXCEPT `~/neovim` for Neovim config)
- ALWAYS ensure tools/configs can be installed via stow or setup script
- CRITICAL: tmux config must ONLY exist at `~/dotfiles/.tmux.conf` — never `.config/tmux/`
- Neovim config lives in `~/neovim` (separate repo, NOT part of dotfiles)

### Symlink Management
- ALWAYS use GNU Stow for all configuration symlinking
- NEVER manually create symlinks or copy config files to home directory
- ALWAYS test stow operations before considering changes complete

## Project Overview

- **Purpose**: Personal macOS dev environment (dotfiles + stow + automated setup)
- **Shell**: Fish (primary), Zsh (secondary with Oh My Zsh)
- **Editor**: Neovim (LazyVim) at `~/neovim`, symlinked to `~/.config/nvim`
- **Terminal**: Ghostty, WezTerm, iTerm2 | **Multiplexer**: tmux with TPM
- **Packages**: Homebrew (`homebrew/Brewfile`) | **LSPs**: Nix-based (`nix/global/`)
- **Theme**: Tokyo Night consistent across all applications

### File Organization
- Application configs: `.config/` subdirectories
- Shell configs: dotfiles root level
- Scripts: `scripts/` directory
- Package management: `homebrew/` directory

### Adding New Tools
- **CLI Tools**: Brewfile → Fish PATH → setup.sh → aliases/functions → Zsh compatibility
- **GUI Apps**: Brewfile cask → setup.sh check → `.config/` subdirectory → Tokyo Night theme
- **Plugins**: Fish=Fisher, tmux=TPM, Neovim=LazyVim (in `~/neovim`)

## Development Standards

- ALWAYS add new packages to `homebrew/Brewfile`
- ALWAYS update `scripts/setup.sh` when adding new tools
- ALWAYS maintain consistent theming (Tokyo Night) across applications
- ALWAYS use Fish shell syntax for primary shell configurations
- ALWAYS include Zsh compatibility for broader system support
- PATH management: add new tool paths to both Fish and setup script

### Core Fish Functions (`.config/fish/functions/`)

| Function | Alias | Description |
|----------|-------|-------------|
| `gwt-dev` | `gwtd` | Create worktree with isolated devcontainer |
| `gwt-ticket` | `gwtt` | Autonomous ticket execution (worktree + agent loop) |
| `gwt-status` | `gwts` | Show worktree + devcontainer status table |
| `gwt-cleanup` | `gwtclean` | Remove stale devcontainer instances |
| `pinchtab-ctl` | `ptctl` | PinchTab Chrome orchestrator management |

## Shell Code Style

### Fish Shell (Primary)
- Functions in `.config/fish/functions/` — one function per file
- Function filename must match function name
- Use `argparse` for flag parsing, `set -l` for locals, `set -gx` for exports
- Use `test` over `[` for conditionals
- String operations: prefer Fish builtins (`string match`, `string replace`)
- Error output: `echo "Error: message" >&2`

### Bash Scripts
- Scripts in `scripts/` directory
- Shebang: `#!/usr/bin/env bash`
- Always `set -euo pipefail` at the top
- Quote all variable expansions: `"$var"` not `$var`
- Functions: lowercase with underscores

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Fish function | kebab-case | `gwt-dev`, `otel-start` |
| Fish alias | short lowercase | `gwtd`, `ptctl` |
| Bash function | snake_case | `install_package` |
| Script file | kebab-case | `setup-mobile-coding.sh` |
| Config dir | lowercase | `.config/ghostty/` |

## Git Commit Standards

- Use conventional commit format: `type: brief description`
- Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`
- NO emojis in commit messages
- NO AI assistant references in commits
- Imperative mood: "add feature" not "added feature"
- Keep subject line under 72 characters

## Testing & Validation

- Fish syntax check: `fish --no-execute <file>`
- Bash syntax check: `bash -n <file>`
- Bash lint: `shellcheck <file>`
- Stow dry-run: `stow --simulate --verbose .`
- Smoke test: `scripts/smoke-test.sh`
- Filtered tests: `scripts/test-filter.sh [group]` (run `--list` for groups)
- Full validation: `scripts/validate-comprehensive.sh`

## Setup Script

- `scripts/setup.sh` is 1500+ lines with 11 phases. Read the relevant phase before editing.
- Profiles: minimal, standard, comprehensive, dev, ops
- New tool additions require: Brewfile entry + setup.sh phase + Fish/Zsh PATH config
- Test with `--dry-run` flag first

## Common Mistakes to Avoid

- Do not create files outside `~/dotfiles` (exception: `~/neovim`)
- Do not add emojis to commit messages
- Do not use `npx` — use `bunx` instead
- Do not manually create symlinks — use stow
- Do not modify Karabiner JSON directly — use the GUI
- Do not sort/reorganize Brewfile — maintain existing grouping
- tmux plugins are managed by TPM, not stow
- LazyVim config lives in `~/neovim`, not here

## Quality Assurance

### Before Committing
- Verify setup script works, stow completes, theme consistency maintained
- Validate Fish and Zsh configurations work correctly

### Troubleshooting
- **Missing PATH**: Add to both Fish config and setup script
- **Theme Inconsistency**: Check Tokyo Night theme application
- **Plugin Failures**: Verify plugin managers are properly configured
- **Stow Conflicts**: Resolve symlink conflicts before deployment
