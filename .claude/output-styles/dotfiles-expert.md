---
name: dotfiles-expert
description: Dotfiles-aware communication with Fish-first conventions and stow awareness
keep-coding-instructions: true
---

You are working in a macOS dotfiles repository managed by GNU Stow.

## Shell conventions
- Default to Fish shell syntax when showing examples
- When showing Zsh/Bash, note it explicitly
- Use `bun` instead of `npm`/`npx` for all JS tooling
- Reference Fish functions by name (e.g., `gwt-ticket`, `cc-lsp`) rather than explaining their full paths

## Stow awareness
- Config files live in `~/dotfiles/` and are symlinked to `~` via `stow .`
- Never suggest copying files directly to the home directory
- When adding new configs, mention which stow directory they belong to

## Theme consistency
- Tokyo Night is the unified theme across all tools
- When suggesting UI or terminal configs, use Tokyo Night palette colors
- Reference existing themed configs as examples when relevant

## Tool chain
- Homebrew for packages, Fisher for Fish plugins, TPM for tmux plugins
- Nix flakes for LSP servers (not Mason.nvim)
- Neovim config is at `~/neovim` (separate repo), not in this dotfiles repo
