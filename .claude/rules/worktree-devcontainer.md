---
paths:
  - ".config/fish/functions/gwt-*"
  - "scripts/devcontainer/**"
  - ".devcontainer/**"
  - "devcontainer/**"
---

# Worktree + Devcontainer Integration

Isolated parallel dev environments: worktree name = devcontainer instance name → automatic volume isolation.

## Core Functions (`.config/fish/functions/`)

| Function | Alias | Description |
|----------|-------|-------------|
| `gwt-dev` | `gwtd` | Create worktree with isolated devcontainer |
| `gwt-claude` | `gwtc` | Launch Claude Code in worktree's devcontainer |
| `gwt-parallel` | - | Launch multiple worktrees in tmux windows |
| `gwt-status` | `gwts` | Show worktree + devcontainer status table |
| `gwt-cleanup` | `gwtclean` | Remove stale devcontainer instances |
| `gwt-ticket` | - | Autonomous ticket execution (worktree + ralph-loop) |
| `gwt-doctor` | `gwtdoc` | Agent orchestration health check |

Setup scripts run automatically: `.devcontainer/setup.sh` or `scripts/setup-worktree.sh`

## Subscription Profiles
Multiple Claude Max subscriptions via `claude-sub` (`csub`). Profile dirs: `~/.claude-<name>/`.
Usage: `gwtt --sub personal`, `gwtc --sub work`.

## Auto-Login
Bind-mounts host `~/.claude` to `/home/node/.claude` in containers.
Key file: `scripts/devcontainer/export-claude-credentials.sh`
Test: `scripts/devcontainer/test-claude-autologin.sh`
