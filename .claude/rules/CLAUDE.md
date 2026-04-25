# Rules Index

Subsystem-specific rules loaded on-demand based on which files you're editing. Each rule file declares its scope via `paths:` frontmatter globs.

## Rule Files

### Conventions (apply to all work)
| File | Scope |
|------|-------|
| `conventions-commit.md` | Git commit message format, types, no-emoji/no-AI rules |
| `conventions-shell-style.md` | Fish (primary) and Bash coding style, naming patterns |
| `conventions-testing.md` | Validation commands (fish --no-execute, bash -n, shellcheck, stow --simulate) |

### Infrastructure
| File | Scope |
|------|-------|
| `hooks.md` | Claude Code lifecycle hooks in `.claude/hooks/` |
| `mcp-servers.md` | MCP server parity between Desktop and CLI configs |
| `lsp-nix.md` | LSP server integration via Nix devShells |
| `otel-observability.md` | OpenTelemetry LGTM stack for Claude Code telemetry |
| `skills-plugins.md` | Skills location standards, plugin marketplace management |

### Workflows
| File | Scope |
|------|-------|
| `agent-orchestration.md` | Multi-agent lifecycle (Gastown patterns, gwt-* functions) |
| `cross-provider.md` | Multi-provider LLM bridge (Codex, Gemini, Ollama, DeepSeek) |
| `obsidian-synthesis.md` | Per-session Obsidian synthesis triggers, reason tags, dedup |
| `ticket-execution.md` | Ticket workflow, queue management, gwt-ticket orchestration |
| `worktree-devcontainer.md` | Devcontainer auto-login, credential binding |

## Navigation

When editing files, check if a rule applies by matching the file path against rule frontmatter `paths:` globs. Convention rules apply broadly; infrastructure and workflow rules apply to specific subsystems.
