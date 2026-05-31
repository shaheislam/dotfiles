# Scripts Index

112 scripts and 20 subdirectories supporting the dotfiles ecosystem. Scripts use `#!/usr/bin/env bash` with `set -euo pipefail`.

## Key Entry Points

| Script | Purpose |
|--------|---------|
| `setup.sh` | Main machine bootstrap (Homebrew, stow, tools, configs) |
| `setup-mobile-coding.sh` | Mosh + Tailscale for remote access |
| `setup-selfhost-llm.sh` | Ollama + Open WebUI local LLM |

## Subdirectories

### Core Infrastructure
| Directory | Purpose |
|-----------|---------|
| `setup/` | macOS defaults, system preferences |
| `harness/` | Drift detection, diagnostics for dotfiles health |
| `lib/` | Shared bash libraries and utilities |
| `bin/` | Standalone executables added to PATH |
| `hooks/` | Git hooks and CI integration |
| `ci-hooks/` | CI-specific hook scripts |
| `tests/` | Shell script tests |
| `profiles/` | Shell profile management |

### Agent & AI
| Directory | Purpose |
|-----------|---------|
| `claude/` | Claude Code helper scripts |
| `codex/` | Codex CLI integration and account management |
| `otel/` | OpenTelemetry LGTM stack (docker-compose, Grafana dashboards) |
| `obsidian/` | Obsidian vault management scripts |
| `openclaw/` | OpenClaw AI platform config |

### DevOps & Containers
| Directory | Purpose |
|-----------|---------|
| `docker/` | Dockerfile and container testing |
| `devcontainer/` | Devcontainer credential export, auto-login |
| `kubernetes/` | K8s helper scripts |
| `manifests/` | K8s manifest files (with README) |
| `linux/` | Linux-specific setup scripts |
| `windows/` | Windows/WSL setup |
| `windows-vm/` | Windows VM provisioning |

### Domain-Specific
| Directory | Purpose |
|-----------|---------|
| `youtube/` | YouTube transcript fetcher (yt-transcript.py) |
| `anki/` | Anki flashcard generation |
| `cv/` | CV compilation and LaTeX tooling |
| `aws/` | AWS helper scripts |
| `tmux/` | tmux hooks, status helpers, session management |
| `pihole/` | Pi-hole DNS management |
| `ticket-queue/` | Ticket queue management |
| `tools/` | Standalone tool scripts |

## Conventions

- Bash scripts: `set -euo pipefail`, quote all variables, snake_case functions
- File naming: kebab-case (e.g., `setup-mobile-coding.sh`)
- Shared code: import from `lib/` directory
- Never use `((var++))` with `set -e` — use `var=$((var + 1))` instead
