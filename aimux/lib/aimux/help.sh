#!/usr/bin/env bash
# aimux help
cat <<'EOF'
aimux - AI Agent Multiplexer
Terminal-agnostic agent orchestration for tmux

USAGE:
  aimux <command> [options]

COMMANDS:
  new <branch>        Create workspace (worktree + tmux window)
  status              Show all workspaces with agent state
  run <ticket> [msg]  Execute ticket autonomously
  attach [name]       Attach to workspace (fzf picker if no name)
  kill <name>         Kill workspace + cleanup worktree
  doctor              Health check
  queue               Ticket queue management
  log [workspace]     View agent output logs
  notify <msg>        Send notification (terminal + native + webhook)
  daemon              Agent state monitoring daemon
  version             Show version
  help                Show this help

ALIASES:
  st = status, a = attach, k = kill, q = queue, l = log, n = notify

EXAMPLES:
  aimux new feature-auth           Create workspace for feature-auth branch
  aimux status                     Show all workspaces with agent state
  aimux run PROJ-123 "Fix bug"     Execute ticket autonomously
  aimux run TASK-456 -P codex      Use Codex provider
  aimux kill feature-auth          Kill workspace and cleanup
  aimux daemon start               Start agent state monitoring
  aimux queue add PROJ-789 "Test"  Add ticket to queue
  aimux queue start                Start queue dispatcher
  aimux log -f my-workspace        Follow workspace logs

CONFIGURATION:
  ~/.aimux/config.toml             Settings (providers, notifications, queue, etc.)

PROVIDERS:
  claude (default), codex, ollama  Built-in providers
  ~/.aimux/providers/              User-defined provider plugins

DOCS: https://github.com/shaheislam/aimux
EOF
