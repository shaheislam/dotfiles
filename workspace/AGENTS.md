# Workspace Agent Guide

Shared agent guidance for repositories under `~/work`.

## Shell Guidance

- Fish is the default interactive shell on this machine.
- For interactive Fish commands, use `set -e VAR` instead of `unset VAR`.
- `env -u VAR command` is valid for one-off command execution from Fish.
- If an example is Bash/Zsh-only, label it explicitly instead of presenting it as generic shell syntax.

## Scope

- These are shared workspace defaults.
- Repo-specific `AGENTS.md` files can add or override guidance for a given repository.
