# Homebrew Agent Guide

Rules for `~/dotfiles/homebrew`.

## Brewfile

- Add Homebrew dependencies to `homebrew/Brewfile`; do not install them with ad hoc `brew install` commands.
- Preserve the existing grouping structure.
- Do not reorganize or sort the Brewfile broadly unless explicitly asked.
- GUI apps belong as casks when appropriate.

## Setup Parity

- New CLI tools must also be handled in `scripts/setup.sh`.
- PATH changes must be reflected in Fish config and setup-script Zsh compatibility where needed.
- MCP package additions must maintain Claude Desktop and Claude Code CLI parity.

## Validation

- Run `scripts/test-filter.sh brewfile` after Brewfile changes.
- Run `scripts/test-filter.sh setup-syntax` if setup wiring changed.
