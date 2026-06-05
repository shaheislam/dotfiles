# Fish Agent Guide

Rules for `~/dotfiles/.config/fish`.

## Fish Syntax

- Fish is the primary interactive shell.
- Use Fish syntax, not Bash syntax: `set`, `test`, and `; and`.
- Do not suggest `unset`; use `set -e VAR` for interactive Fish guidance.
- `env -u VAR command` is acceptable for one-off command execution.
- Label Bash/Zsh-only snippets explicitly.

## File Layout

- Fish functions go in `.config/fish/functions/<name>.fish` as individual files.
- Do not add new functions inline in `config.fish`.
- Read the relevant `config.fish` section before editing; do not rewrite the whole file.
- Completions belong in `.config/fish/completions/` unless an existing function-local pattern is already used.

## Validation

- Run `fish -n .config/fish/config.fish` after config changes.
- Run `fish -n .config/fish/functions/<name>.fish` for edited functions.
- Test loadable functions with `fish -c 'source .config/fish/functions/<name>.fish; functions -q <name>'`.
- Run `scripts/test-filter.sh fish` for Fish changes.
