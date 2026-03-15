---
title: CI/CD Integration
description: Using aimux in CI/CD pipelines and headless environments
---

## Overview

aimux can run in headless CI/CD environments where there is no interactive terminal. Since it uses tmux as its substrate, it works anywhere tmux can run -- including Docker containers, GitHub Actions runners, and remote servers.

## Headless execution

In CI, you typically do not have a tmux session already running. Start one programmatically:

```bash
# Start a detached tmux session
tmux new-session -d -s ci

# Run aimux within that session
TMUX= tmux send-keys -t ci "cd /workspace && aimux run PROJ-123 'Fix the bug'" Enter
```

Or use a script that manages the tmux lifecycle:

```bash
#!/bin/bash
set -euo pipefail

# Start tmux
tmux new-session -d -s ci -c "$WORKSPACE"

# Queue tickets
aimux queue add "$TICKET_KEY" "$TICKET_PROMPT" --provider "${PROVIDER:-claude}"
aimux queue start

# Wait for completion by polling state files
while true; do
    status=$(aimux status --json | jq -r ".[0].status // empty")
    case "$status" in
        completed|done) echo "Ticket completed"; break ;;
        failed) echo "Ticket failed"; exit 1 ;;
        *) sleep 30 ;;
    esac
done

# Collect results
aimux log "$TICKET_KEY" > /tmp/agent-output.log
```

## GitHub Actions example

```yaml
name: AI Agent Ticket
on:
  workflow_dispatch:
    inputs:
      ticket:
        description: 'Ticket key'
        required: true
      prompt:
        description: 'Task description'
        required: true

jobs:
  execute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y tmux jq

      - name: Install aimux
        run: |
          git clone https://github.com/shaheislam/aimux.git /tmp/aimux
          cd /tmp/aimux && make install PREFIX=$HOME/.local
          echo "$HOME/.local/bin" >> $GITHUB_PATH

      - name: Install AI agent
        run: |
          # Install Claude Code or your preferred agent
          # npm install -g @anthropic-ai/claude-code

      - name: Run ticket
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          tmux new-session -d -s ci -c "$GITHUB_WORKSPACE"
          aimux run ${{ inputs.ticket }} "${{ inputs.prompt }}" --no-witness
          # Wait for agent to finish (simplified)
          sleep 300
          aimux log ${{ inputs.ticket }}

      - name: Commit results
        run: |
          git add -A
          git diff --cached --quiet || git commit -m "feat: ${{ inputs.ticket }}"
          git push
```

## Docker container usage

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    tmux git bash jq curl \
    && rm -rf /var/lib/apt/lists/*

# Install aimux
COPY . /opt/aimux
RUN cd /opt/aimux && make install

# Install your AI agent
# RUN npm install -g @anthropic-ai/claude-code

ENTRYPOINT ["aimux"]
```

Run it:

```bash
docker run --rm \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -v "$PWD:/workspace" \
  aimux-runner run PROJ-123 "Fix the bug"
```

## Remote server execution

For long-running tasks on a remote server:

```bash
# SSH into the server
ssh dev-server

# Start aimux in a tmux session
tmux new-session -d -s agents
tmux send-keys -t agents "cd /path/to/repo" Enter
tmux send-keys -t agents "aimux run PROJ-123 'Fix the bug'" Enter

# Detach and disconnect
# The agent continues running in tmux

# Reconnect later to check status
ssh dev-server
tmux attach -t agents
aimux status
```

## Environment variables for CI

| Variable | Purpose |
|----------|---------|
| `AIMUX_HOME` | Override config directory (default: `~/.aimux`) |
| `AIMUX_POLL_INTERVAL` | Daemon/witness poll interval |
| `AIMUX_STUCK_TIMEOUT` | Seconds before marking stuck |
| `AIMUX_DEFAULT_PROVIDER` | Default provider |
| `ANTHROPIC_API_KEY` | For Claude provider |
| `OPENAI_API_KEY` | For Codex provider |

## Notes

- In headless environments, use `--no-witness` if you have your own monitoring
- The `--json` flag on `aimux status` is useful for programmatic result checking
- tmux must be available for aimux to function -- install it in your CI image
- For short-lived CI jobs, consider polling state files directly instead of using the daemon
- The queue system works in CI for executing multiple tickets sequentially with rate limiting
