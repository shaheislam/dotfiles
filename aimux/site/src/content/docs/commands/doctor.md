---
title: aimux doctor
description: Health check for the agent orchestration stack
---

## Usage

```bash
aimux doctor
```

## Description

Runs a comprehensive health check across all components of the aimux stack: dependencies, tmux status, daemon processes, git worktrees, configuration, state files, and available AI providers.

## Options

| Flag | Description |
|------|-------------|
| `--help` / `-h` | Show help |

## Check categories

### Dependencies

Verifies required and optional commands are installed.

| Command | Required | Purpose |
|---------|----------|---------|
| `tmux` | Yes | Terminal multiplexing |
| `git` | Yes | Worktree management |
| `bash` | Yes | CLI runtime |
| `fzf` | No | Interactive workspace picker |
| `jq` | No | JSON parsing for state and queue |
| `docker` | No | Devcontainer support |

Required commands that are missing produce a `FAIL` result. Optional commands produce a `WARN`.

### tmux Status

Checks whether the tmux server is running and reports the number of active sessions.

### Agent Watcher

Checks whether the aimux daemon is running by looking for the PID file at `/tmp/aimux-daemon.pid` and verifying the process is alive. Also checks for the legacy `tmux-claude-watcher.sh` process.

### Git Worktrees

If you are inside a git repository, reports the number of worktrees and checks for prunable (stale) worktree references.

### Configuration

Checks for:
- `~/.aimux/` directory existence
- `~/.aimux/config.toml` file
- `aimuxd` Go daemon binary (optional)

### State Health

If the state directory exists:
- Counts tracked state files
- Checks for orphaned state files (state files that reference worktree paths that no longer exist)

### AI Providers

Enumerates all available providers (via the provider plugin system) and checks whether each provider's command binary is installed:

```
AI Providers
  [PASS] provider: claude (claude)
  [PASS] provider: codex (codex)
  [WARN] provider: ollama (ollama) — command not found
```

Falls back to direct binary checks for `claude` and `codex` if the provider system is not available.

## Result types

| Result | Meaning |
|--------|---------|
| `PASS` | Check passed, component is healthy |
| `WARN` | Non-critical issue, aimux will work but with reduced functionality |
| `FAIL` | Critical issue, aimux may not function correctly |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | All checks passed (warnings are acceptable) |
| `1` | One or more checks failed |

## Summary

The final line reports totals:

```
Summary: 13 checks, 2 warnings, 0 failures
```

## Example output

```
aimux doctor

Dependencies
  [PASS] tmux
  [PASS] git
  [PASS] bash
  [PASS] fzf
  [PASS] jq
  [WARN] docker — not installed (optional)

tmux Status
  [PASS] tmux server running (2 sessions)

Agent Watcher
  [WARN] agent watcher daemon — not running (start with: aimux daemon start)

Git Worktrees
  [PASS] git repo detected (3 worktrees)

Configuration
  [PASS] ~/.aimux directory
  [PASS] config.toml
  [WARN] aimuxd (Go daemon) — not found (optional, bash daemon used as fallback)

State Health
  [PASS] state files (1 tracked)

AI Providers
  [PASS] provider: claude (claude)
  [PASS] provider: codex (codex)
  [WARN] provider: ollama (ollama) — command not found

Summary: 13 checks, 4 warnings, 0 failures
```

## Notes

- Run `aimux doctor` after installation to verify everything is set up correctly
- The doctor command does not modify any state or configuration
- Use the output to diagnose issues before filing bug reports
- Prunable worktree warnings can be fixed with `git worktree prune`
