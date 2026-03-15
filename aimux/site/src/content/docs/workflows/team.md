---
title: Team Workflows
description: How multiple developers can use aimux on the same repository
---

## Overview

aimux is designed as a single-user tool, but teams can adopt shared patterns to coordinate agent work across developers. Each developer runs their own aimux instance, and git is the synchronization layer.

## Branch naming conventions

Adopt a convention so worktrees do not collide across team members:

```bash
# Developer A
aimux run AUTH-001 "Fix session timeout"
# Creates branch: auth-001

# Developer B
aimux run AUTH-002 "Add MFA support"
# Creates branch: auth-002
```

Since aimux derives branch names from ticket keys (lowercased, special characters replaced with dashes), using unique ticket keys from your issue tracker naturally prevents branch conflicts.

## Shared remote workflow

The standard team workflow:

1. Each developer runs aimux locally against their own clone
2. Agents create branches and commit locally
3. Developers review changes, then push branches to the shared remote
4. Pull requests are created for code review
5. After merge, `aimux kill` cleans up the local worktree

```bash
# Developer A: autonomous ticket execution
aimux run PROJ-100 "Implement OAuth2 login"

# When complete, review and push
aimux attach proj-100
cd ~/projects/myapp-proj-100
git diff
git push origin proj-100

# Create PR (via CLI or web UI)
gh pr create --title "PROJ-100: Implement OAuth2 login" --body "Agent-generated"

# After merge, clean up
aimux kill proj-100
```

## Shared server setup

For teams that want a single shared machine running agents:

### Separate tmux sessions per developer

```bash
# Developer A starts their session
tmux new-session -s alice
aimux run PROJ-100 "Fix auth" --provider claude

# Developer B starts their session
tmux new-session -s bob
aimux run PROJ-200 "Add tests" --provider codex
```

### Separate AIMUX_HOME directories

Each developer uses their own state directory:

```bash
# Developer A
export AIMUX_HOME=/home/alice/.aimux
aimux run PROJ-100 "Fix auth"

# Developer B
export AIMUX_HOME=/home/bob/.aimux
aimux run PROJ-200 "Add tests"
```

This prevents state file conflicts since each developer's workspaces are tracked independently.

## Queue-based task distribution

Use a shared queue file for distributing work:

```bash
# Tech lead queues tickets for the day
aimux queue add PROJ-100 "Fix login CSS" --priority 10
aimux queue add PROJ-101 "Add validation" --priority 8
aimux queue add PROJ-102 "Refactor queries" --priority 5 --provider codex
aimux queue add PROJ-103 "Write tests" --priority 3
aimux queue add PROJ-104 "Update docs" --priority 1

# Start the dispatcher
aimux queue start

# All tickets are dispatched to agents running on this machine
```

## Code review for agent output

Treat agent-generated code the same as human code:

1. **Always review before merging**: Agents can produce incorrect or insecure code
2. **Run tests**: Verify the agent's changes do not break anything
3. **Check for quality**: Look for hardcoded values, missing error handling, security issues
4. **Use linting**: Ensure code style matches team standards

```bash
# Review an agent's work
aimux attach proj-100
cd ~/projects/myapp-proj-100

# Run tests
npm test

# Lint
npm run lint

# Manual review
git diff main...proj-100
```

## Tips for teams

- **Standardize prompts**: Create prompt templates for common task types so agents produce consistent results
- **Use the same config**: Share `config.toml` settings (poll interval, stuck timeout) across the team for predictable behavior
- **Monitor resource usage**: When multiple team members run agents on the same machine, CPU and memory can be constrained
- **Coordinate API keys**: Each developer should use their own API keys to avoid rate limit contention
- **Document provider preferences**: Agree on which provider works best for which task types

## What aimux does not do

- **Multi-user state sharing**: Each aimux instance has its own state directory. There is no built-in mechanism for shared state across developers.
- **Access control**: aimux does not restrict which branches or tickets a developer can use.
- **Centralized monitoring**: Each developer's daemon monitors their own workspaces. A shared dashboard would need to be built separately.

For same-repo collaboration with multiple agents, aimux focuses on giving each developer powerful local tooling. Coordination happens through git and your existing team processes.
