# Devcontainer Agent Guide

Rules for `~/dotfiles/devcontainer`.

## Worktree Containers

- `devcon.fish` owns devcontainer lifecycle; do not create separate container managers.
- The devcon sandbox in `~/dotfiles/devcontainer/claude-code-plugins/` is built-in.
- Do not require projects to have their own `.devcontainer/` directory to use `devcon`.
- All tmux panes in devcontainer windows should run inside the container via `devcontainer exec`.
- When a container process exits, panes should re-enter the container shell rather than dropping to the host.

## Validation

- Run `scripts/devcontainer/test-claude-autologin.sh` for Claude credential or autologin changes.
- Run targeted Docker or devcontainer checks when lifecycle scripts change.
