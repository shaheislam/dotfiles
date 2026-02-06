# Dotfiles Agent Guide

This file documents specific behaviors and constraints for AI agents working on this repository. Each rule addresses a concrete mistake agents repeatedly make.

## File Locations

- The tmux config is at `~/dotfiles/.tmux.conf` in the repo root. NEVER create `.config/tmux/tmux.conf` - it will conflict with the stow symlink.
- Neovim config is NOT in this repo. It lives at `~/neovim` (separate repository). Do not create or modify nvim configs here.
- Fish functions go in `.config/fish/functions/<name>.fish` as individual files, not inline in `config.fish`.
- All dotfiles are symlinked via GNU Stow from `~/dotfiles` to `~`. Do not manually create symlinks.

## Shell Scripts

- Fish is the primary shell. Write new shell functions in Fish syntax, not Bash.
- When modifying `config.fish`, it is 2800+ lines. Read the relevant section first, do not rewrite the entire file.
- Fish shell uses `set` not `export`. Fish uses `; and` not `&&`. Fish uses `test` not `[[ ]]`.
- All new CLI tools must be added to BOTH `homebrew/Brewfile` AND `scripts/setup.sh`.
- PATH additions must go in both Fish config AND `scripts/setup.sh` (Zsh section) for compatibility.

## Package Management

- Use `bun`/`bunx` instead of `npm`/`npx`/`yarn`/`pnpm`. The `use_bun.py` hook will block npm commands.
- Homebrew packages go in `homebrew/Brewfile`, not installed via `brew install` in scripts.
- MCP servers must be configured in BOTH Claude Desktop config AND Claude Code CLI. Check both.

## Testing

- Run `scripts/smoke-test.sh` to validate basic dotfiles integrity.
- Run `scripts/validate-macos.sh` to check macOS-specific configurations.
- For Fish functions, test by sourcing the file: `source .config/fish/functions/<name>.fish`.
- There are no unit test frameworks for shell scripts - test by execution.
- Docker tests exist at `scripts/docker/` for Linux compatibility. Start Colima first.

## Available Tools for Agents

- `scripts/test-filter.sh [group]` - **Filtered test runner** (preferred for quick feedback). Run `--list` to see groups: fish, stow, claude, setup-syntax, brewfile, mcp, tmux, hooks, agents-md.
- `scripts/smoke-test.sh` - Quick validation of dotfiles setup.
- `scripts/validate-comprehensive.sh` - Full validation suite (slow).
- `scripts/test-lsp-inheritance.sh` - Verify LSP isolation works correctly.
- `scripts/pihole/test-pihole-setup.sh` - Test Pi-hole DNS setup.
- `scripts/devcontainer/test-claude-autologin.sh` - Test Claude autologin in devcontainers.
- `.claude/hooks/use_bun.py` - Enforces bun over npm (PreToolUse hook).
- `.claude/hooks/validate-bash.py` - Blocks dangerous bash commands (PreToolUse hook).

## Git Worktree Functions

- The `gwt-*` functions in `.config/fish/functions/` are the core worktree system.
- `gwt-dev.fish` creates worktrees with devcontainer isolation.
- `gwt-ticket.fish` (530 lines) is the autonomous ticket executor - read it before modifying.
- `devcon.fish` handles all devcontainer lifecycle - do not create separate container management.

## Common Mistakes to Avoid

- Do not add emojis to commit messages.
- Do not reference AI tools in commit messages.
- Do not create files outside `~/dotfiles` (exception: `~/neovim`).
- Do not use `npx` for MCP commands in setup.sh - use `bunx`.
- Do not modify `.claude/settings.json` directly - plugins are managed via `claude plugin` commands.
- Do not create README.md files unless explicitly asked.
- Do not add Tokyo Night theme configs without checking all tools for consistency.

## Setup Script

- `scripts/setup.sh` is 1500+ lines with 11 phases. Read the relevant phase before editing.
- The setup script supports profiles: minimal, standard, comprehensive, dev, ops.
- New tool additions require: Brewfile entry + setup.sh phase + Fish/Zsh PATH config.
- Test setup changes with `--dry-run` flag first.

## When NOT to Use Agents for This Repo

- Karabiner-Elements config: use the GUI app, the JSON is complex and auto-generated.
- tmux plugin installation: TPM handles this, just add to `.tmux.conf`.
- Brewfile sorting/organization: maintain the existing grouping structure.
- LazyVim plugin config: this lives in `~/neovim`, not here.
