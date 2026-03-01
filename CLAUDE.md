# Claude Code Rules for Dotfiles

> Extends `~/.claude/CLAUDE.md`. Subsystem docs in `.claude/rules/` (loaded on-demand by path).

## Core Rules

### Setup Script Compatibility
- ALWAYS check if `scripts/setup.sh` needs modification when adding new tools
- ALWAYS verify new dependencies are in the Brewfile and setup script
- ALWAYS ensure PATH configs are added to both Fish and Zsh configs

### File Location Constraints
- NEVER create or modify files outside `~/dotfiles` (EXCEPT `~/neovim` for Neovim config)
- ALWAYS ensure tools/configs can be installed via stow or setup script
- CRITICAL: tmux config must ONLY exist at `~/dotfiles/.tmux.conf` — never `.config/tmux/`
- Neovim config lives in `~/neovim` (separate repo, NOT part of dotfiles)

### Symlink Management
- ALWAYS use GNU Stow for all configuration symlinking
- NEVER manually create symlinks or copy config files to home directory
- ALWAYS test stow operations before considering changes complete

## Project Overview

- **Purpose**: Personal macOS dev environment (dotfiles + stow + automated setup)
- **Shell**: Fish (primary), Zsh (secondary with Oh My Zsh)
- **Editor**: Neovim (LazyVim) at `~/neovim`, symlinked to `~/.config/nvim`
- **Terminal**: Ghostty, WezTerm, iTerm2 | **Multiplexer**: tmux with TPM
- **Packages**: Homebrew (`homebrew/Brewfile`) | **LSPs**: Nix-based (`nix/global/`)
- **Theme**: Tokyo Night consistent across all applications

### File Organization
- Application configs → `.config/` subdirectories
- Shell configs → dotfiles root level
- Scripts → `scripts/` directory
- Package management → `homebrew/` directory

### Adding New Tools
- **CLI Tools**: Brewfile → Fish PATH → setup.sh → aliases/functions → Zsh compatibility
- **GUI Apps**: Brewfile cask → setup.sh check → `.config/` subdirectory → Tokyo Night theme
- **Plugins**: Fish=Fisher, tmux=TPM, Neovim=LazyVim (in `~/neovim`)

## Development Standards

- ALWAYS add new packages to `homebrew/Brewfile`
- ALWAYS update `scripts/setup.sh` when adding new tools
- ALWAYS maintain consistent theming (Tokyo Night) across applications
- ALWAYS use Fish shell syntax for primary shell configurations
- ALWAYS include Zsh compatibility for broader system support
- PATH management: add new tool paths to both Fish and setup script

**Core Functions** (`.config/fish/functions/`):
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

**Subscription Profiles**: Multiple Claude Max subscriptions via `claude-sub` (`csub`). Profile dirs: `~/.claude-<name>/`. Usage: `gwtt --sub personal`, `gwtc --sub work`.

### Claude Code Devcontainer Auto-Login
Auto-authenticates Claude Code inside devcontainers by bind-mounting the host's `~/.claude` directory directly.
All containers share the same config directory — credentials, plugins, settings, and hooks are all available. When any container refreshes OAuth tokens, all others see the update immediately.
- **Key File**: `scripts/devcontainer/export-claude-credentials.sh` (exports Keychain to `~/.claude`, idempotent, `--force` to overwrite)
- **Mount**: `~/.claude` (bind-mounted to `/home/node/.claude` in containers)
- **Test**: `scripts/devcontainer/test-claude-autologin.sh`

### Claude & Opencode Activity Watcher
Background daemon monitoring tmux windows for idle processes: `scripts/tmux/tmux-claude-watcher.sh`
- ● = Claude idle, ◆ = Opencode idle, ●◆ = Both idle
- ⚠ = Ralph-loop stuck (iteration unchanged for >10min, GUPP violation detection)

### Agent Orchestration (Gastown Patterns)
Multi-agent lifecycle management. Scripts in `scripts/`, each supports `--help`.

**Core Scripts**: `agent-state.sh` (derive state from ground truth, ZFC pattern), `worktree-witness.sh` (lifecycle monitor, auto-spawned by gwt-ticket), `merge-queue.sh` (serialized merges), `agent-triage.sh` (intelligent restart: START/WAKE/NUDGE/NOTHING), `phase-gates.sh` (pause on external conditions).

**Agent States**: `running` | `idle` | `stuck` | `completed` | `dead` | `none`

**Workflow Templates** (`templates/workflows/*.toml`): `implement`, `bugfix`, `refactor`, `test` — used via `gwt-ticket --template`.

**Higher-Level Orchestration**:
- **Convoys** (`convoy.sh`): Batch work tracking, group related tickets. JSONL at `~/.claude/convoys.jsonl`.
- **Molecules** (`molecule.sh`): Durable multi-step workflows with checkpoints and resume.
- **Town Beads** (`town-beads.sh`): Cross-project memory sync. **On by default** in gwt-ticket (`--no-town` to disable).
- **Mayor** (`gwt-mayor.sh`): Global coordinator daemon, LaunchAgent at `com.dotfiles.gwt-mayor.plist`.
- **Dashboard** (`agent-dashboard.sh`): Web dashboard at `http://127.0.0.1:8787`.

**gwt-ticket orchestration flags**: `--convoy NAME|ID`, `--plan NAME [specs]`, `--molecule [id]`, `--town` (default on), `--no-town`, `--mayor`, `--no-mayor`.

**Plan Orchestration** (`gwtt --plan`): Spawn multiple gwtt runs as a convoy. Sources: inline specs, `--file tasks.md`, or `--decompose "goal"`. Options: `--stagger N`, `--dry-run`. Resume: `gwtt-plan resume <name>`. Queue: `gwt-queue add-plan <name> --file tasks.md`.

### Beads Agent Memory
Git-backed agent memory that persists across sessions. Auto-initialized in worktrees by `gwt-ticket`.
- **CLI**: `bd` (installed via Homebrew)
- **Hooks**: SessionStart (`bd prime`), PreCompact (`bd sync`) — no-ops if project has no `.beads/`
- **Per-worktree**: `gwt-ticket` runs `bd init --quiet` automatically
- **Completion**: `worktree-witness.sh` and `ticket-complete.sh` run `bd sync` before merge/PR
- **Commands**: `/beads:ready` (prime context), `/beads:create` (create issue)

### Checkpoints (Session Context ↔ Git Commits)
Managed by the upstream `entire` CLI ([entireio/cli](https://github.com/entireio/cli)). Session metadata stored on `entire/checkpoints/v1` orphan branch. Strategies: `manual-commit` (default, shadow branches) or `auto-commit`.

- **Installation**: `brew tap entireio/tap && brew install entireio/tap/entire`
- **Hooks**: `entire enable` installs 7 Claude Code hooks (SessionStart, SessionEnd, UserPromptSubmit, Stop, PreToolUse/Task, PostToolUse/Task, PostToolUse/TodoWrite)
- **Per-worktree**: `gwt-ticket` runs `entire enable` automatically (`--no-checkpoints` to opt out)
- **Key commands**: `entire enable`, `entire status`, `entire explain <sha>`, `entire resume`, `entire rewind`, `entire doctor`
- **Fish alias**: `ckpt` wraps `entire` with backward-compatible command translation
- **Worktree support**: Shadow branches per worktree (`entire/<base>-<worktree-hash>`)
- **Coexistence**: Complements Beads (issue-level) — different granularity, no conflict.

### MCP Server Integration

**CRITICAL MCP Configuration Parity Rule**:
- **ALWAYS** ensure MCP servers are configured in BOTH Claude Desktop AND Claude Code CLI
- **ALWAYS** maintain parity between both configurations
- **ALWAYS** update both simultaneously when adding/removing MCP servers

**MCP Configuration Locations**:
1. **Claude Desktop**: `~/dotfiles/Library/Application Support/Claude/claude_desktop_config.json` (stow symlink)
2. **Claude Code CLI**: `claude mcp add` commands in `scripts/setup.sh` (Phase 4)
   - Use `bunx` instead of `npx` (per hook requirements)
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx run` for other Python MCPs

**Adding New MCP Servers**:
1. Add to Claude Desktop config (`claude_desktop_config.json`)
2. Add to setup script via `claude mcp add` command
3. Verify: restart Claude Desktop, run `claude mcp list`
4. Test MCP server functionality in both environments

**MCP Server Types**:
- **Browser-Based** (browser-tools, drawio): Require browser extension, add to Brewfile, version-specific packages
- **AWS**: `uvx awslabs.<server-name>@latest`, ensure GraphViz installed, both configs required
- **Python**: `pipx run mcp-server-<name>` in setup script
- **API-based**: Disable by default, document API key requirements

**Verify Parity**: `claude mcp list` and `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers | keys'`

### Agentic Ticket Execution System
Autonomously execute tickets from Linear/Jira using devcontainers + ralph-loop.

| Command | Description |
|---------|-------------|
| `/todo <desc>` | Create ticket in Linear/Jira (auto-detected) |
| `/ticket-execute [KEY]` | Execute ticket autonomously |
| `gwt-ticket` | Core function: worktree + tmux + ralph-loop |
| `ticket-execute` / `tex` | High-level orchestrator |

**Ticketing detection**: `.claude/settings.local.json` → `.linear.toml` → git remote patterns → default Linear.
See `gwt-ticket --help` for full options.

### Ticket Queue (Rate-Limit-Aware Multi-Sub Scheduling)
Queue tickets for auto-execution when usage limits reset. Daemon auto-dispatches to lowest-utilization subscription profile.

**Commands**: `gwt-queue add|list|remove|start|stop|status|usage|profiles|next|log`. Fish: `.config/fish/functions/gwt-queue.fish`.
**Multi-Sub**: `--sub NAME` pins to profile; without it, auto-dispatches to lowest 5-hour utilization.
**Config env vars**: `QUEUE_POLL_INTERVAL` (300s), `QUEUE_THRESHOLD` (80%), `QUEUE_COOLDOWN` (600s).
**Files**: Queue data at `~/.claude/ticket-queue.json`, scripts at `scripts/ticket-queue/`.

### Docker Container Testing for Linux Compatibility
Test dotfiles on Linux distributions via Colima + Docker. Location: `scripts/docker/`. See `scripts/docker/README.md`.
- **ALWAYS** test cross-platform changes in containers (start with Ubuntu)
- **ALWAYS** verify stow operations and shell configs load without errors
- **NEVER** skip container testing when making cross-platform changes

### Mobile Coding Setup (Personal Devices Only)
Remote dev from mobile via Mosh + Tailscale. **Personal devices only** - separate from setup.sh.
Script: `scripts/setup-mobile-coding.sh`. Mobile tmux layout: `scripts/tmux/tmux-mobile-session.sh`

### Clawdbot AI Assistant (Optional)
WhatsApp/Telegram interface to Claude. Installed via `scripts/setup-mobile-coding.sh` or `npm install -g clawdbot@latest`.

### OpenClaw AI Assistant Platform
Self-hosted multi-channel AI inbox (Telegram, Slack, Discord, WhatsApp, Signal, WebChat). Docs: `docs/openclaw-setup.md`.

**Commands**: `openclaw start|stop|status|doctor|send|audit|pair|agent` (alias: `claw`). Fish: `.config/fish/functions/openclaw.fish`.
**Security**: Loopback binding, token auth, DM pairing, sandbox for non-main sessions. Config: `scripts/openclaw/openclaw-base.json`.
**Notifications**: `oc_notify()` in `scripts/openclaw/notify.sh` for gwt-ticket, ralph-loop, merge-queue integration.
**Runtime state**: `~/.openclaw/` (NOT in git). Tests: `scripts/test-filter.sh openclaw`.

### DNS Configuration
Cloudflare DNS (1.1.1.1, 1.0.0.1) configured in `scripts/setup/macos-defaults.sh` to bypass UK ISP DNS blocking.

### Pi-hole DNS Ad Blocking
Local DNS ad blocking via Colima + Docker. Location: `scripts/pihole/`. Fish wrapper: `pihole start|stop|dns-on|dns-off|status`

### Keyboard Remapping
Karabiner-Elements: `.config/karabiner/karabiner.json` (stow managed). Caps Lock ↔ Escape swap. Edit via GUI app.

### Claude Code Settings & Security

Multi-scope configuration following official best practices. Reference: https://code.claude.com/docs/en/settings

**Settings Scope Hierarchy** (higher overrides lower):
1. **Managed** (`managed-settings.json`) — organizational policy (not used for personal dotfiles)
2. **Local** (`.claude/settings.local.json`) — per-project personal overrides
3. **Project** (`.claude/settings.json`) — shared project config
4. **User** (`~/.claude/settings.json` → symlinked from dotfiles) — global defaults

**Schema Validation**: All `settings.json` files include `$schema` for IDE autocompletion and validation.

**Permission Rules** (`~/.claude/settings.json`):
- **Allow**: Common safe commands (git, bun, fish, stow, nix, brew, jq, `--version`, `--help`)
- **Deny**: Sensitive files (`.env`, `secrets/`, SSH keys, AWS creds, GPG keys), destructive commands (`rm -rf /`, `chmod -R 777`, pipe-to-shell)
- Rules use gitignore-style patterns: `//` absolute, `~/` home, `/` project root, `./` current dir
- Evaluation order: deny → ask → allow (first match wins)

**Sandbox Configuration** (`~/.claude.json`, set by `setup.sh`):
- OS-level filesystem + network isolation for Bash commands (macOS Seatbelt)
- `autoAllowBashIfSandboxed: true` — sandboxed commands skip permission prompts
- `excludedCommands: ["docker", "colima"]` — tools incompatible with sandbox
- `allowWrite: ["~/.kube", "//tmp", "~/.cache", "~/.local"]` — subprocess write paths
- `denyRead: ["~/.aws/credentials", "~/.ssh/id_*", "~/.gnupg/private-keys-v1.d"]` — credential protection

**Attribution** (`~/.claude.json`, set by `setup.sh`):
- `attribution.commit: ""` and `attribution.pr: ""` — suppress default AI attribution trailers
- Enforces CLAUDE.md rule: never reference AI assistants in commits

**Model Configuration**:
- Default: Opus 4.6 (Max plan), falls back to Sonnet on usage threshold
- `CLAUDE_CODE_EFFORT_LEVEL=high` in Fish config — maximum adaptive reasoning
- `/model opusplan` — Opus for planning, Sonnet for execution

**Environment Variables** (`.config/fish/config.fish`):
- `FORCE_AUTOUPDATE_PLUGINS=1` — auto-update plugins on session start
- `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` — load CLAUDE.md from `--add-dir` paths
- `CLAUDE_CODE_EFFORT_LEVEL=high` — Opus 4.6 adaptive reasoning effort
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — multi-agent coordination (in `settings.json` env block)

### Claude Code Hooks

Lifecycle hooks for deterministic control over Claude Code behavior. See `docs/claude-code-hooks.md` for complete reference.

**Hook Events Configured** (`.claude/settings.json`):

| Event | Hooks | Purpose |
|-------|-------|---------|
| **SessionStart** | `fix-hookify-imports.sh`, `bd prime`, `lsp-status.sh` | Plugin fixes, Beads memory, LSP context |
| **PreToolUse** (Bash) | `use_bun.py`, `validate-bash.py` | Bun enforcement, dangerous command blocking |
| **PostToolUse** (Read) | `deepwiki-context.py` | Language-aware DeepWiki repo suggestions |
| **PreCompact** | `bd sync` | Beads memory sync before compaction |
| **Notification** | `macos_notification.py`, `log-notification.sh` | Desktop alerts, audit logging |
| **UserPromptSubmit** | `nvim-bridge.sh` | Neovim editor context |
| **Stop** | `cross-provider-bridge.sh` | Cross-provider review |
| **SubagentStart** | `log-notification.sh` | Subagent lifecycle logging |
| **SubagentStop** | `log-notification.sh` | Subagent lifecycle logging |

> **Note**: Checkpoint hooks are now managed by `entire enable` (see Checkpoints section).

**Hook Types**: Command (shell scripts), Prompt (LLM yes/no), Agent (multi-turn with tools)

**Hook Scripts**: `.claude/hooks/` (Python/Bash scripts, symlinked via stow)

**Testing**: `scripts/test-filter.sh hooks` (44 tests: permissions, syntax, wiring, functional). Standalone: `scripts/test-hooks.sh` for detailed output.

**Adding New Hooks**:
1. Create script in `.claude/hooks/` (make executable)
2. Wire in `.claude/settings.json` under appropriate event
3. Add tests in `scripts/test-hooks.sh`
4. Update `docs/claude-code-hooks.md`

### Skills & Skill Sources

All custom commands have been migrated to `.claude/skills/` (24 skills). See `docs/skills-reference.md` for the complete guide.

**Best sources** (ranked by quality):
1. **[anthropics/skills](https://github.com/anthropics/skills)** - Official Anthropic skills (document processing, design, development)
2. **[obra/superpowers](https://github.com/obra/superpowers)** - Most mature community framework (20+ skills, dev methodology)
3. **[VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills)** - 380+ skills from Vercel, Cloudflare, Trail of Bits, etc.
4. **[daymade/claude-code-skills](https://github.com/daymade/claude-code-skills)** - 37 production-ready skills

**Key locations**: Personal `~/.claude/skills/`, Project `.claude/skills/`

**Cross-tool standard**: [agentskills.io](https://agentskills.io/specification) - skills work in Claude Code, Codex, Gemini CLI, Cursor, Copilot.

### Claude Code Subagents
Custom subagents in `.claude/agents/` (Markdown files with YAML frontmatter). Loaded at session start; Claude auto-delegates based on descriptions.

**12 Domain Specialists** (referenced in `.claude/AGENTS.md`):

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| `architect` | inherit | Read-only + Bash | System design reviews, architecture analysis |
| `frontend` | inherit | Full | UI components, accessibility, responsive design |
| `backend` | inherit | Full | API development, data integrity, reliability |
| `security` | inherit | Read-only + Bash | Threat modeling, vulnerability detection |
| `performance` | inherit | Read-only + Bash | Bottleneck analysis, optimization |
| `analyzer` | inherit | Read-only + Edit | Root cause debugging, systematic investigation |
| `qa` | inherit | Read-only + Bash | Test creation, validation, quality assurance |
| `refactorer` | inherit | Full | Code cleanup, deduplication, modernization |
| `devops` | inherit | Full | CI/CD, containerization, automation |
| `devops-security-auditor` | inherit | Read-only + Bash | Infrastructure security, container hardening |
| `mentor` | haiku | Read-only + Bash | Teaching, explanations, knowledge transfer |
| `scribe` | inherit | Read + Write/Edit | Documentation, technical writing |

**3 Project-Specific Agents**:

<<<<<<< HEAD
| Agent | Model | Purpose |
|-------|-------|---------|
| `shell-expert` | inherit | Fish/Bash specialist for this dotfiles project |
| `test-runner` | haiku | Runs test suites and reports results (background) |
| `dotfiles-doctor` | haiku | Health checks for stow, symlinks, themes, tools |

**Key features**: `memory: project` on architect (cross-session learning), `background: true` on test-runner (concurrent), `maxTurns` on haiku agents (cost control), `skills: fish-reload, dotfiles-sync` on shell-expert (preloaded context), `mcpServers: deepwiki` on architect and mentor (repo documentation access).
**Lifecycle hooks**: SubagentStart/SubagentStop events in `.claude/settings.json` for logging.
**Docs**: `.claude/AGENTS.md` for full reference, [official docs](https://code.claude.com/docs/en/sub-agents) for frontmatter spec.
**Tests**: `scripts/test-filter.sh subagents` (155 tests).

**Testing**: `scripts/test-filter.sh subagents` (137 tests: file existence, frontmatter validation, name matching, tool/model validity, AGENTS.md link integrity).

### Claude Code Plugins
14 plugins from 4 marketplaces + 9 LSP plugins from `boostvolt/claude-code-lsps`. Stored in `~/.claude/settings.json`, installation commands in `scripts/setup.sh`.

Plugins are installed from four marketplaces:
- `anthropics/claude-code` (alias: `claude-code-plugins`) - Official Anthropic plugins
- `kenryu42/cc-marketplace` (alias: `cc-marketplace`) - Community safety plugins
- `antonbabenko/terraform-skill` (alias: `antonbabenko`) - Terraform/OpenTofu development skill
- `steveyegge/beads` - Git-backed agent memory and issue tracking

**Recommended additional marketplaces** (install via `/plugin marketplace add`):
- `anthropics/skills` - Official skills (document processing, design, mcp-builder)
- `obra/superpowers-marketplace` - Superpowers dev methodology framework
- `daymade/claude-code-skills` - 37 community skills

**Installation**: Plugins stored in `~/.claude/settings.json`. For cross-device consistency, installation commands are in `scripts/setup.sh`.

**Installed Plugins (14 total)**:

| Plugin | Command | Purpose |
|--------|---------|---------|
| **code-review** | `/code-review` | Automated PR review with 4 parallel agents, 80+ confidence filtering |
| **pr-review-toolkit** | Auto-triggered | 6 specialized reviewers (comments, tests, errors, types, quality, simplicity) |
| **hookify** | `/hookify` | Create hooks via markdown (also `/hookify:list`, `/hookify:configure`) |
| **feature-dev** | `/feature-dev` | 7-phase feature development workflow |
| **frontend-design** | Auto-activated | Production-grade UI generation, anti-AI aesthetics |
| **plugin-dev** | `/plugin-dev:create-plugin` | 7 skills + 8-phase plugin creation workflow |
| **ralph-wiggum** | `/ralph-wiggum:ralph-loop` | Autonomous iteration loops (also `/ralph-wiggum:cancel-ralph`) |
| **agent-sdk-dev** | `/new-sdk-app` | Claude Agent SDK project scaffolding |
| **explanatory-output-style** | SessionStart hook | Educational insights on implementation choices |
| **learning-output-style** | SessionStart hook | Interactive learning mode with code contribution prompts |
| **code-simplifier** | Auto-triggered | Identifies over-engineering, suggests simpler implementations |
| **security-guidance** | Auto-triggered | Security best practices, vulnerability detection, compliance guidance |
| **terraform-skill** | Auto-activated | Terraform/OpenTofu module development, testing frameworks, CI/CD workflows |
| **beads** | `/beads:ready`, `/beads:create` | Git-backed agent memory, in-repo issue tracking with DAG dependencies |

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Cost**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.
**Env vars**: `FORCE_AUTOUPDATE_PLUGINS=1`, `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (set in `config.fish`).
**Settings**: `teammateMode: "auto"` in `~/.claude.json`. Auto-Compact enabled (default).

### Claude Code LSP Integration
Native LSP servers for Claude Code — real-time diagnostics, go-to-definition, find-references without IDE dependency. Docs: `docs/claude-code-lsp.md`.

**Marketplace**: `boostvolt/claude-code-lsps` (22 languages). Installed via `scripts/setup.sh`.
**Installed plugins**: pyright (Python), typescript (TS/JS), gopls (Go), rust-analyzer (Rust), bash-lsp (Bash), yaml-lsp (YAML), terraform (HCL), lua-lsp (Lua), nix-lsp (Nix).
**LSP binaries**: Reuses Nix global devShell binaries (`nix/global/`). Same binaries serve both Neovim and Claude Code.
**Fish command**: `cc-lsp status|install|doctor` — check/manage LSP integration.
**SessionStart hook**: `lsp-status.sh` injects available LSP servers into Claude's context.
**LSP tool operations**: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`.
**Tests**: `scripts/test-filter.sh lsp`

### Neovim-Claude Code Bridge
Event-driven bridge giving Claude Code awareness of Neovim editor state. Docs: `docs/nvim-claude-bridge.md`.

**Architecture**: Neovim autocommands write to `/tmp/nvim-claude-bridge/<hash>/state.json`, Claude Code's `UserPromptSubmit` hook reads it before each prompt.
**Sections**: diagnostics (errors/warnings), focus (file/line/filetype), git_hunks (gitsigns), tests (neotest results).
**Staleness**: Per-section timestamps; sections >5 min old are omitted.
**Files**: `~/neovim/lua/config/claude-bridge.lua` (writer), `.claude/hooks/nvim-bridge.sh` (reader), `.config/fish/functions/cc-bridge.fish` (management).
**Fish command**: `cc-bridge status|cat|clean|help`.
**Tests**: `scripts/test-filter.sh nvim-bridge`

### Claude Code Remote Control
Continue local Claude Code sessions from phone, tablet, or any browser via claude.ai/code or the Claude mobile app. Session runs locally; remote interface is just a window into it.

**Setup**: `scripts/setup.sh` enables `enableRemoteControl = true` in `~/.claude.json` (globally, all sessions).
**Fish command**: `cc-rc start|status|enable|disable|tmux|help` — manage Remote Control sessions.
**CLI**: `claude remote-control` (new session), `/remote-control` or `/rc` (from existing session).
**Flags**: `--verbose` (detailed logs), `--sandbox`/`--no-sandbox` (filesystem/network isolation).
**Requirements**: Max plan, authenticated via `/login`, workspace trust accepted.
**Security**: Outbound HTTPS only, no inbound ports. All traffic via Anthropic API over TLS.
**Tests**: `scripts/test-filter.sh remote-control`

### Claude Code Agent Teams (Experimental)
Coordinate multiple Claude Code instances with shared tasks and messaging. Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**Config**: `teammateMode = "auto"` (tmux split panes), override: `claude --teammate-mode in-process`.
**Controls**: `Shift+Up/Down` navigate, `Shift+Tab` delegate, `Ctrl+T` task list.
**When to use**: Same-repo collaborative work. Use `gwt-parallel` for isolated multi-branch, `gwt-ticket` for autonomous single-ticket.
**Best practices**: Assign different files per teammate, provide specific context (no inherited history), 5-6 tasks per teammate.
||||||| c16409d
**Installed Plugins (14 total)**:

| Plugin | Command | Purpose |
|--------|---------|---------|
| **code-review** | `/code-review` | Automated PR review with 4 parallel agents, 80+ confidence filtering |
| **pr-review-toolkit** | Auto-triggered | 6 specialized reviewers (comments, tests, errors, types, quality, simplicity) |
| **hookify** | `/hookify` | Create hooks via markdown (also `/hookify:list`, `/hookify:configure`) |
| **feature-dev** | `/feature-dev` | 7-phase feature development workflow |
| **frontend-design** | Auto-activated | Production-grade UI generation, anti-AI aesthetics |
| **plugin-dev** | `/plugin-dev:create-plugin` | 7 skills + 8-phase plugin creation workflow |
| **ralph-wiggum** | `/ralph-wiggum:ralph-loop` | Autonomous iteration loops (also `/ralph-wiggum:cancel-ralph`) |
| **agent-sdk-dev** | `/new-sdk-app` | Claude Agent SDK project scaffolding |
| **explanatory-output-style** | SessionStart hook | Educational insights on implementation choices |
| **learning-output-style** | SessionStart hook | Interactive learning mode with code contribution prompts |
| **code-simplifier** | Auto-triggered | Identifies over-engineering, suggests simpler implementations |
| **security-guidance** | Auto-triggered | Security best practices, vulnerability detection, compliance guidance |
| **terraform-skill** | Auto-activated | Terraform/OpenTofu module development, testing frameworks, CI/CD workflows |
| **beads** | `/beads:ready`, `/beads:create` | Git-backed agent memory, in-repo issue tracking with DAG dependencies |

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Cost**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.
**Env vars**: `FORCE_AUTOUPDATE_PLUGINS=1`, `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (set in `config.fish`).
**Settings**: `teammateMode: "auto"` in `~/.claude.json`. Auto-Compact enabled (default).

### Claude Code LSP Integration
Native LSP servers for Claude Code — real-time diagnostics, go-to-definition, find-references without IDE dependency. Docs: `docs/claude-code-lsp.md`.

**Marketplace**: `boostvolt/claude-code-lsps` (22 languages). Installed via `scripts/setup.sh`.
**Installed plugins**: pyright (Python), typescript (TS/JS), gopls (Go), rust-analyzer (Rust), bash-lsp (Bash), yaml-lsp (YAML), terraform (HCL), lua-lsp (Lua), nix-lsp (Nix).
**LSP binaries**: Reuses Nix global devShell binaries (`nix/global/`). Same binaries serve both Neovim and Claude Code.
**Fish command**: `cc-lsp status|install|doctor` — check/manage LSP integration.
**SessionStart hook**: `lsp-status.sh` injects available LSP servers into Claude's context.
**LSP tool operations**: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`.
**Tests**: `scripts/test-filter.sh lsp`

### Neovim-Claude Code Bridge
Event-driven bridge giving Claude Code awareness of Neovim editor state. Docs: `docs/nvim-claude-bridge.md`.

**Architecture**: Neovim autocommands write to `/tmp/nvim-claude-bridge/<hash>/state.json`, Claude Code's `UserPromptSubmit` hook reads it before each prompt.
**Sections**: diagnostics (errors/warnings), focus (file/line/filetype), git_hunks (gitsigns), tests (neotest results).
**Staleness**: Per-section timestamps; sections >5 min old are omitted.
**Files**: `~/neovim/lua/config/claude-bridge.lua` (writer), `.claude/hooks/nvim-bridge.sh` (reader), `.config/fish/functions/cc-bridge.fish` (management).
**Fish command**: `cc-bridge status|cat|clean|help`.
**Tests**: `scripts/test-filter.sh nvim-bridge`

### Claude Code Remote Control
Continue local Claude Code sessions from phone, tablet, or any browser via claude.ai/code or the Claude mobile app. Session runs locally; remote interface is just a window into it.

**Setup**: `scripts/setup.sh` enables `enableRemoteControl = true` in `~/.claude.json` (globally, all sessions).
**Fish command**: `cc-rc start|status|enable|disable|tmux|help` — manage Remote Control sessions.
**CLI**: `claude remote-control` (new session), `/remote-control` or `/rc` (from existing session).
**Flags**: `--verbose` (detailed logs), `--sandbox`/`--no-sandbox` (filesystem/network isolation).
**Requirements**: Max plan, authenticated via `/login`, workspace trust accepted.
**Security**: Outbound HTTPS only, no inbound ports. All traffic via Anthropic API over TLS.
**Tests**: `scripts/test-filter.sh remote-control`

### Claude Code Agent Teams (Experimental)
Coordinate multiple Claude Code instances with shared tasks and messaging. Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**Config**: `teammateMode = "auto"` (tmux split panes), override: `claude --teammate-mode in-process`.
**Controls**: `Shift+Up/Down` navigate, `Shift+Tab` delegate, `Ctrl+T` task list.
**When to use**: Same-repo collaborative work. Use `gwt-parallel` for isolated multi-branch, `gwt-ticket` for autonomous single-ticket.
**Best practices**: Assign different files per teammate, provide specific context (no inherited history), 5-6 tasks per teammate.
||||||| 48897be
**Core Functions** (`.config/fish/functions/`):
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

**Subscription Profiles**: Multiple Claude Max subscriptions via `claude-sub` (`csub`). Profile dirs: `~/.claude-<name>/`. Usage: `gwtt --sub personal`, `gwtc --sub work`.

### Claude Code Devcontainer Auto-Login
Auto-authenticates Claude Code inside devcontainers by bind-mounting the host's `~/.claude` directory directly.
All containers share the same config directory — credentials, plugins, settings, and hooks are all available. When any container refreshes OAuth tokens, all others see the update immediately.
- **Key File**: `scripts/devcontainer/export-claude-credentials.sh` (exports Keychain to `~/.claude`, idempotent, `--force` to overwrite)
- **Mount**: `~/.claude` (bind-mounted to `/home/node/.claude` in containers)
- **Test**: `scripts/devcontainer/test-claude-autologin.sh`

### Claude & Opencode Activity Watcher
Background daemon monitoring tmux windows for idle processes: `scripts/tmux/tmux-claude-watcher.sh`
- ● = Claude idle, ◆ = Opencode idle, ●◆ = Both idle
- ⚠ = Ralph-loop stuck (iteration unchanged for >10min, GUPP violation detection)

### Agent Orchestration (Gastown Patterns)
Multi-agent lifecycle management. Scripts in `scripts/`, each supports `--help`.

**Core Scripts**: `agent-state.sh` (derive state from ground truth, ZFC pattern), `worktree-witness.sh` (lifecycle monitor, auto-spawned by gwt-ticket), `merge-queue.sh` (serialized merges), `agent-triage.sh` (intelligent restart: START/WAKE/NUDGE/NOTHING), `phase-gates.sh` (pause on external conditions).

**Agent States**: `running` | `idle` | `stuck` | `completed` | `dead` | `none`

**Workflow Templates** (`templates/workflows/*.toml`): `implement`, `bugfix`, `refactor`, `test` — used via `gwt-ticket --template`.

**Higher-Level Orchestration**:
- **Convoys** (`convoy.sh`): Batch work tracking, group related tickets. JSONL at `~/.claude/convoys.jsonl`.
- **Molecules** (`molecule.sh`): Durable multi-step workflows with checkpoints and resume.
- **Town Beads** (`town-beads.sh`): Cross-project memory sync. **On by default** in gwt-ticket (`--no-town` to disable).
- **Mayor** (`gwt-mayor.sh`): Global coordinator daemon, LaunchAgent at `com.dotfiles.gwt-mayor.plist`.
- **Dashboard** (`agent-dashboard.sh`): Web dashboard at `http://127.0.0.1:8787`.

**gwt-ticket orchestration flags**: `--convoy NAME|ID`, `--plan NAME [specs]`, `--molecule [id]`, `--town` (default on), `--no-town`, `--mayor`, `--no-mayor`.

**Plan Orchestration** (`gwtt --plan`): Spawn multiple gwtt runs as a convoy. Sources: inline specs, `--file tasks.md`, or `--decompose "goal"`. Options: `--stagger N`, `--dry-run`. Resume: `gwtt-plan resume <name>`. Queue: `gwt-queue add-plan <name> --file tasks.md`.

### Beads Agent Memory
Git-backed agent memory that persists across sessions. Auto-initialized in worktrees by `gwt-ticket`.
- **CLI**: `bd` (installed via Homebrew)
- **Hooks**: SessionStart (`bd prime`), PreCompact (`bd sync`) — no-ops if project has no `.beads/`
- **Per-worktree**: `gwt-ticket` runs `bd init --quiet` automatically
- **Completion**: `worktree-witness.sh` and `ticket-complete.sh` run `bd sync` before merge/PR
- **Commands**: `/beads:ready` (prime context), `/beads:create` (create issue)

### Checkpoints (Session Context ↔ Git Commits)
Links session transcript slices to commit SHAs on `checkpoints/v1` orphan branch. CLI: `ckpt` (Fish wrapper for `scripts/checkpoints.sh`). Run `ckpt --help` for commands.

- **Hooks**: UserPromptSubmit (pre-prompt state), Stop (capture transcript slice)
- **Per-worktree**: `gwt-ticket` runs `checkpoints enable` automatically (`--no-checkpoints` to opt out)
- **Key commands**: `ckpt enable`, `ckpt show <sha>`, `ckpt resume`, `ckpt context`, `ckpt search`, `ckpt doctor`
- **Coexistence**: Complements Beads (issue-level) — different granularity, no conflict.

### MCP Server Integration

**CRITICAL MCP Configuration Parity Rule**:
- **ALWAYS** ensure MCP servers are configured in BOTH Claude Desktop AND Claude Code CLI
- **ALWAYS** maintain parity between both configurations
- **ALWAYS** update both simultaneously when adding/removing MCP servers

**MCP Configuration Locations**:
1. **Claude Desktop**: `~/dotfiles/Library/Application Support/Claude/claude_desktop_config.json` (stow symlink)
2. **Claude Code CLI**: `claude mcp add` commands in `scripts/setup.sh` (Phase 4)
   - Use `bunx` instead of `npx` (per hook requirements)
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx run` for other Python MCPs

**Adding New MCP Servers**:
1. Add to Claude Desktop config (`claude_desktop_config.json`)
2. Add to setup script via `claude mcp add` command
3. Verify: restart Claude Desktop, run `claude mcp list`
4. Test MCP server functionality in both environments

**MCP Server Types**:
- **Browser-Based** (browser-tools, drawio): Require browser extension, add to Brewfile, version-specific packages
- **AWS**: `uvx awslabs.<server-name>@latest`, ensure GraphViz installed, both configs required
- **Python**: `pipx run mcp-server-<name>` in setup script
- **API-based**: Disable by default, document API key requirements

**Verify Parity**: `claude mcp list` and `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers | keys'`

### Agentic Ticket Execution System
Autonomously execute tickets from Linear/Jira using devcontainers + ralph-loop.

| Command | Description |
|---------|-------------|
| `/todo <desc>` | Create ticket in Linear/Jira (auto-detected) |
| `/ticket-execute [KEY]` | Execute ticket autonomously |
| `gwt-ticket` | Core function: worktree + tmux + ralph-loop |
| `ticket-execute` / `tex` | High-level orchestrator |

**Ticketing detection**: `.claude/settings.local.json` → `.linear.toml` → git remote patterns → default Linear.
See `gwt-ticket --help` for full options.

### Ticket Queue (Rate-Limit-Aware Multi-Sub Scheduling)
Queue tickets for auto-execution when usage limits reset. Daemon auto-dispatches to lowest-utilization subscription profile.

**Commands**: `gwt-queue add|list|remove|start|stop|status|usage|profiles|next|log`. Fish: `.config/fish/functions/gwt-queue.fish`.
**Multi-Sub**: `--sub NAME` pins to profile; without it, auto-dispatches to lowest 5-hour utilization.
**Config env vars**: `QUEUE_POLL_INTERVAL` (300s), `QUEUE_THRESHOLD` (80%), `QUEUE_COOLDOWN` (600s).
**Files**: Queue data at `~/.claude/ticket-queue.json`, scripts at `scripts/ticket-queue/`.

### Docker Container Testing for Linux Compatibility
Test dotfiles on Linux distributions via Colima + Docker. Location: `scripts/docker/`. See `scripts/docker/README.md`.
- **ALWAYS** test cross-platform changes in containers (start with Ubuntu)
- **ALWAYS** verify stow operations and shell configs load without errors
- **NEVER** skip container testing when making cross-platform changes

### Mobile Coding Setup (Personal Devices Only)
Remote dev from mobile via Mosh + Tailscale. **Personal devices only** - separate from setup.sh.
Script: `scripts/setup-mobile-coding.sh`. Mobile tmux layout: `scripts/tmux/tmux-mobile-session.sh`

### Clawdbot AI Assistant (Optional)
WhatsApp/Telegram interface to Claude. Installed via `scripts/setup-mobile-coding.sh` or `npm install -g clawdbot@latest`.

### OpenClaw AI Assistant Platform
Self-hosted multi-channel AI inbox (Telegram, Slack, Discord, WhatsApp, Signal, WebChat). Docs: `docs/openclaw-setup.md`.

**Commands**: `openclaw start|stop|status|doctor|send|audit|pair|agent` (alias: `claw`). Fish: `.config/fish/functions/openclaw.fish`.
**Security**: Loopback binding, token auth, DM pairing, sandbox for non-main sessions. Config: `scripts/openclaw/openclaw-base.json`.
**Notifications**: `oc_notify()` in `scripts/openclaw/notify.sh` for gwt-ticket, ralph-loop, merge-queue integration.
**Runtime state**: `~/.openclaw/` (NOT in git). Tests: `scripts/test-filter.sh openclaw`.

### DNS Configuration
Cloudflare DNS (1.1.1.1, 1.0.0.1) configured in `scripts/setup/macos-defaults.sh` to bypass UK ISP DNS blocking.

### Pi-hole DNS Ad Blocking
Local DNS ad blocking via Colima + Docker. Location: `scripts/pihole/`. Fish wrapper: `pihole start|stop|dns-on|dns-off|status`

### Keyboard Remapping
Karabiner-Elements: `.config/karabiner/karabiner.json` (stow managed). Caps Lock ↔ Escape swap. Edit via GUI app.

### Claude Code Hooks

Lifecycle hooks for deterministic control over Claude Code behavior. See `docs/claude-code-hooks.md` for complete reference.

**Hook Events Configured** (`.claude/settings.json`):

| Event | Hooks | Purpose |
|-------|-------|---------|
| **SessionStart** | `fix-hookify-imports.sh`, `bd prime`, `lsp-status.sh` | Plugin fixes, Beads memory, LSP context |
| **PreToolUse** (Bash) | `use_bun.py`, `validate-bash.py` | Bun enforcement, dangerous command blocking |
| **PostToolUse** (Read) | `deepwiki-context.py` | Language-aware DeepWiki repo suggestions |
| **PreCompact** | `bd sync` | Beads memory sync before compaction |
| **Notification** | `macos_notification.py`, `log-notification.sh` | Desktop alerts, audit logging |
| **UserPromptSubmit** | `checkpoint-pre-prompt.sh`, `nvim-bridge.sh` | Checkpoint capture, Neovim editor context |
| **Stop** | `checkpoint-capture.sh`, `cross-provider-bridge.sh` | Checkpoint capture, cross-provider review |

**Hook Types**: Command (shell scripts), Prompt (LLM yes/no), Agent (multi-turn with tools)

**Hook Scripts**: `.claude/hooks/` (Python/Bash scripts, symlinked via stow)

**Testing**: `scripts/test-filter.sh hooks` (44 tests: permissions, syntax, wiring, functional). Standalone: `scripts/test-hooks.sh` for detailed output.

**Adding New Hooks**:
1. Create script in `.claude/hooks/` (make executable)
2. Wire in `.claude/settings.json` under appropriate event
3. Add tests in `scripts/test-hooks.sh`
4. Update `docs/claude-code-hooks.md`

### Skills & Skill Sources

All custom commands have been migrated to `.claude/skills/` (24 skills). See `docs/skills-reference.md` for the complete guide.

**Best sources** (ranked by quality):
1. **[anthropics/skills](https://github.com/anthropics/skills)** - Official Anthropic skills (document processing, design, development)
2. **[obra/superpowers](https://github.com/obra/superpowers)** - Most mature community framework (20+ skills, dev methodology)
3. **[VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills)** - 380+ skills from Vercel, Cloudflare, Trail of Bits, etc.
4. **[daymade/claude-code-skills](https://github.com/daymade/claude-code-skills)** - 37 production-ready skills

**Key locations**: Personal `~/.claude/skills/`, Project `.claude/skills/`

**Cross-tool standard**: [agentskills.io](https://agentskills.io/specification) - skills work in Claude Code, Codex, Gemini CLI, Cursor, Copilot.

### Claude Code Plugins
14 plugins from 4 marketplaces + 9 LSP plugins from `boostvolt/claude-code-lsps`. Stored in `~/.claude/settings.json`, installation commands in `scripts/setup.sh`.

Plugins are installed from four marketplaces:
- `anthropics/claude-code` (alias: `claude-code-plugins`) - Official Anthropic plugins
- `kenryu42/cc-marketplace` (alias: `cc-marketplace`) - Community safety plugins
- `antonbabenko/terraform-skill` (alias: `antonbabenko`) - Terraform/OpenTofu development skill
- `steveyegge/beads` - Git-backed agent memory and issue tracking

**Recommended additional marketplaces** (install via `/plugin marketplace add`):
- `anthropics/skills` - Official skills (document processing, design, mcp-builder)
- `obra/superpowers-marketplace` - Superpowers dev methodology framework
- `daymade/claude-code-skills` - 37 community skills

**Installation**: Plugins stored in `~/.claude/settings.json`. For cross-device consistency, installation commands are in `scripts/setup.sh`.

**Installed Plugins (14 total)**:

| Plugin | Command | Purpose |
|--------|---------|---------|
| **code-review** | `/code-review` | Automated PR review with 4 parallel agents, 80+ confidence filtering |
| **pr-review-toolkit** | Auto-triggered | 6 specialized reviewers (comments, tests, errors, types, quality, simplicity) |
| **hookify** | `/hookify` | Create hooks via markdown (also `/hookify:list`, `/hookify:configure`) |
| **feature-dev** | `/feature-dev` | 7-phase feature development workflow |
| **frontend-design** | Auto-activated | Production-grade UI generation, anti-AI aesthetics |
| **plugin-dev** | `/plugin-dev:create-plugin` | 7 skills + 8-phase plugin creation workflow |
| **ralph-wiggum** | `/ralph-wiggum:ralph-loop` | Autonomous iteration loops (also `/ralph-wiggum:cancel-ralph`) |
| **agent-sdk-dev** | `/new-sdk-app` | Claude Agent SDK project scaffolding |
| **explanatory-output-style** | SessionStart hook | Educational insights on implementation choices |
| **learning-output-style** | SessionStart hook | Interactive learning mode with code contribution prompts |
| **code-simplifier** | Auto-triggered | Identifies over-engineering, suggests simpler implementations |
| **security-guidance** | Auto-triggered | Security best practices, vulnerability detection, compliance guidance |
| **terraform-skill** | Auto-activated | Terraform/OpenTofu module development, testing frameworks, CI/CD workflows |
| **beads** | `/beads:ready`, `/beads:create` | Git-backed agent memory, in-repo issue tracking with DAG dependencies |

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Cost**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.
**Env vars**: `FORCE_AUTOUPDATE_PLUGINS=1`, `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (set in `config.fish`).
**Settings**: `teammateMode: "auto"` in `~/.claude.json`. Auto-Compact enabled (default).

### Claude Code LSP Integration
Native LSP servers for Claude Code — real-time diagnostics, go-to-definition, find-references without IDE dependency. Docs: `docs/claude-code-lsp.md`.

**Marketplace**: `boostvolt/claude-code-lsps` (22 languages). Installed via `scripts/setup.sh`.
**Installed plugins**: pyright (Python), typescript (TS/JS), gopls (Go), rust-analyzer (Rust), bash-lsp (Bash), yaml-lsp (YAML), terraform (HCL), lua-lsp (Lua), nix-lsp (Nix).
**LSP binaries**: Reuses Nix global devShell binaries (`nix/global/`). Same binaries serve both Neovim and Claude Code.
**Fish command**: `cc-lsp status|install|doctor` — check/manage LSP integration.
**SessionStart hook**: `lsp-status.sh` injects available LSP servers into Claude's context.
**LSP tool operations**: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`.
**Tests**: `scripts/test-filter.sh lsp`

### Neovim-Claude Code Bridge
Event-driven bridge giving Claude Code awareness of Neovim editor state. Docs: `docs/nvim-claude-bridge.md`.

**Architecture**: Neovim autocommands write to `/tmp/nvim-claude-bridge/<hash>/state.json`, Claude Code's `UserPromptSubmit` hook reads it before each prompt.
**Sections**: diagnostics (errors/warnings), focus (file/line/filetype), git_hunks (gitsigns), tests (neotest results).
**Staleness**: Per-section timestamps; sections >5 min old are omitted.
**Files**: `~/neovim/lua/config/claude-bridge.lua` (writer), `.claude/hooks/nvim-bridge.sh` (reader), `.config/fish/functions/cc-bridge.fish` (management).
**Fish command**: `cc-bridge status|cat|clean|help`.
**Tests**: `scripts/test-filter.sh nvim-bridge`

### Claude Code Remote Control
Continue local Claude Code sessions from phone, tablet, or any browser via claude.ai/code or the Claude mobile app. Session runs locally; remote interface is just a window into it.

**Setup**: `scripts/setup.sh` enables `enableRemoteControl = true` in `~/.claude.json` (globally, all sessions).
**Fish command**: `cc-rc start|status|enable|disable|tmux|help` — manage Remote Control sessions.
**CLI**: `claude remote-control` (new session), `/remote-control` or `/rc` (from existing session).
**Flags**: `--verbose` (detailed logs), `--sandbox`/`--no-sandbox` (filesystem/network isolation).
**Requirements**: Max plan, authenticated via `/login`, workspace trust accepted.
**Security**: Outbound HTTPS only, no inbound ports. All traffic via Anthropic API over TLS.
**Tests**: `scripts/test-filter.sh remote-control`

### Claude Code Agent Teams (Experimental)
Coordinate multiple Claude Code instances with shared tasks and messaging. Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**Config**: `teammateMode = "auto"` (tmux split panes), override: `claude --teammate-mode in-process`.
**Controls**: `Shift+Up/Down` navigate, `Shift+Tab` delegate, `Ctrl+T` task list.
**When to use**: Same-repo collaborative work. Use `gwt-parallel` for isolated multi-branch, `gwt-ticket` for autonomous single-ticket.
**Best practices**: Assign different files per teammate, provide specific context (no inherited history), 5-6 tasks per teammate.
=======
### LSP Management
- Three-tier system: Global baseline → Project override → Neovim detection
- Use Nix flakes for project-specific LSP versions (not Mason.nvim)
- See `nix/README.md` for architecture and inheritance patterns
=======
**Installed Plugins (14 total)**:

| Plugin | Command | Purpose |
|--------|---------|---------|
| **code-review** | `/code-review` | Automated PR review with 4 parallel agents, 80+ confidence filtering |
| **pr-review-toolkit** | Auto-triggered | 6 specialized reviewers (comments, tests, errors, types, quality, simplicity) |
| **hookify** | `/hookify` | Create hooks via markdown (also `/hookify:list`, `/hookify:configure`) |
| **feature-dev** | `/feature-dev` | 7-phase feature development workflow |
| **frontend-design** | Auto-activated | Production-grade UI generation, anti-AI aesthetics |
| **plugin-dev** | `/plugin-dev:create-plugin` | 7 skills + 8-phase plugin creation workflow |
| **ralph-wiggum** | `/ralph-wiggum:ralph-loop` | Autonomous iteration loops (also `/ralph-wiggum:cancel-ralph`) |
| **agent-sdk-dev** | `/new-sdk-app` | Claude Agent SDK project scaffolding |
| **explanatory-output-style** | SessionStart hook | Educational insights on implementation choices |
| **learning-output-style** | SessionStart hook | Interactive learning mode with code contribution prompts |
| **code-simplifier** | Auto-triggered | Identifies over-engineering, suggests simpler implementations |
| **security-guidance** | Auto-triggered | Security best practices, vulnerability detection, compliance guidance |
| **terraform-skill** | Auto-activated | Terraform/OpenTofu module development, testing frameworks, CI/CD workflows |
| **beads** | `/beads:ready`, `/beads:create` | Git-backed agent memory, in-repo issue tracking with DAG dependencies |

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Cost**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.
**Env vars**: `FORCE_AUTOUPDATE_PLUGINS=1`, `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (set in `config.fish`).
**Settings**: `teammateMode: "auto"` in `~/.claude.json`. Auto-Compact enabled (default).

### Claude Code LSP Integration
Native LSP servers for Claude Code — real-time diagnostics, go-to-definition, find-references without IDE dependency. Docs: `docs/claude-code-lsp.md`.

**Marketplace**: `boostvolt/claude-code-lsps` (22 languages). Installed via `scripts/setup.sh`.
**Installed plugins**: pyright (Python), typescript (TS/JS), gopls (Go), rust-analyzer (Rust), bash-lsp (Bash), yaml-lsp (YAML), terraform (HCL), lua-lsp (Lua), nix-lsp (Nix).
**LSP binaries**: Reuses Nix global devShell binaries (`nix/global/`). Same binaries serve both Neovim and Claude Code.
**Fish command**: `cc-lsp status|install|doctor` — check/manage LSP integration.
**SessionStart hook**: `lsp-status.sh` injects available LSP servers into Claude's context.
**LSP tool operations**: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`.
**Tests**: `scripts/test-filter.sh lsp`

### Neovim-Claude Code Bridge
Event-driven bridge giving Claude Code awareness of Neovim editor state. Docs: `docs/nvim-claude-bridge.md`.

**Architecture**: Neovim autocommands write to `/tmp/nvim-claude-bridge/<hash>/state.json`, Claude Code's `UserPromptSubmit` hook reads it before each prompt.
**Sections**: diagnostics (errors/warnings), focus (file/line/filetype), git_hunks (gitsigns), tests (neotest results).
**Staleness**: Per-section timestamps; sections >5 min old are omitted.
**Files**: `~/neovim/lua/config/claude-bridge.lua` (writer), `.claude/hooks/nvim-bridge.sh` (reader), `.config/fish/functions/cc-bridge.fish` (management).
**Fish command**: `cc-bridge status|cat|clean|help`.
**Tests**: `scripts/test-filter.sh nvim-bridge`

### Claude Code Remote Control
Continue local Claude Code sessions from phone, tablet, or any browser via claude.ai/code or the Claude mobile app. Session runs locally; remote interface is just a window into it.

**Setup**: `scripts/setup.sh` enables `enableRemoteControl = true` in `~/.claude.json` (globally, all sessions).
**Fish command**: `cc-rc start|status|enable|disable|tmux|help` — manage Remote Control sessions.
**CLI**: `claude remote-control` (new session), `/remote-control` or `/rc` (from existing session).
**Flags**: `--verbose` (detailed logs), `--sandbox`/`--no-sandbox` (filesystem/network isolation).
**Requirements**: Max plan, authenticated via `/login`, workspace trust accepted.
**Security**: Outbound HTTPS only, no inbound ports. All traffic via Anthropic API over TLS.
**Tests**: `scripts/test-filter.sh remote-control`

### Claude Code Agent Teams (Experimental)
Coordinate multiple Claude Code instances with shared tasks and messaging. Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**Config**: `teammateMode = "auto"` (tmux split panes), override: `claude --teammate-mode in-process`.
**Controls**: `Shift+Up/Down` navigate, `Shift+Tab` delegate, `Ctrl+T` task list.
**When to use**: Same-repo collaborative work. Use `gwt-parallel` for isolated multi-branch, `gwt-ticket` for autonomous single-ticket.
**Best practices**: Assign different files per teammate, provide specific context (no inherited history), 5-6 tasks per teammate.

### LSP Management
- Three-tier system: Global baseline → Project override → Neovim detection
- Use Nix flakes for project-specific LSP versions (not Mason.nvim)
- See `nix/README.md` for architecture and inheritance patterns
>>>>>>> mergeconflict

## Quality Assurance

### Before Committing
- Verify setup script works, stow completes, theme consistency maintained
- Validate Fish and Zsh configurations work correctly

### Troubleshooting
- **Missing PATH**: Add to both Fish config and setup script
- **Theme Inconsistency**: Check Tokyo Night theme application
- **Plugin Failures**: Verify plugin managers are properly configured
- **Stow Conflicts**: Resolve symlink conflicts before deployment

## Agent Workflow Guidance

- Practical agent rules in root `AGENTS.md`
- **Slam dunks**: `gwt-ticket` or `ralph-loop` for well-defined tasks
- **Research**: Surveying fields, producing comparison summaries
- **Single Agent Rule**: One background agent at a time

### When NOT to Use Agents
- Karabiner-Elements config (use GUI), Brewfile organization, tmux plugin installation (TPM)
- Theme consistency verification, 1Password/SSH setup, stow conflict resolution
- LazyVim plugin config (lives in `~/neovim`)

### Kubernetes Manifests
- ALWAYS place manifests in `scripts/manifests/` with descriptive filenames
- ALWAYS update `scripts/manifests/README.md` with usage and purpose

### Claude Pipeline (Multi-Model Reasoning Chains)
Chain models in terminal: `claude-pipeline` / `cpipe`. Default: opus→sonnet. Docs: `docs/claude-pipeline.md`.

**Presets**: `review` (opus→sonnet→haiku), `cheap` (sonnet→haiku), `local` (ollama→sonnet), `council`, `redteam`.
**Custom**: `--reason MODEL --execute MODEL`, `--stages N`, `--save /tmp/out`, `--dry-run`. Supports piped input.
**In-TUI**: `/model opusplan` auto-switches opus (plan) → sonnet (execution) within a session.

### Self-Hosted LLM Infrastructure
Local LLM stack (Ollama + Open WebUI) as resilience layer. Setup: `scripts/setup-selfhost-llm.sh`.

**Fish commands**: `llm`, `llm-code`, `llm-chat`, `llm-status`, `llm-pull`, `llm-web`. Coding agents: `opencode-local`, `claude-local`.
**Default models**: qwen3-coder (coding agents), qwen2.5-coder:7b, llama3.1:8b, mistral:7b. Env overrides: `LLM_DEFAULT_MODEL`, `LLM_CODE_MODEL`.
**API**: OpenAI-compatible at `http://localhost:11434/v1`. OpenCode config: `.config/opencode/opencode.json` (stow managed).
**Testing**: `scripts/test-selfhost-llm.sh` (`--live` for runtime tests)

### Cross-Provider Reasoning Bridge
Stop hook for correlation-bias mitigation — sends reasoning to independent AI providers. Iterative consensus with graceful fallback chain.

**Enable**: `CROSS_PROVIDER_BRIDGE=1 claude` | **Providers**: Codex, Gemini, Ollama, DeepSeek, Claude, OpenCode
**Key env vars**: `CROSS_PROVIDER_ORDER` (default: `codex,opencode`), `CROSS_PROVIDER_MODE` (`review|redteam|steelman|assumptions`), `CROSS_PROVIDER_MAX_ITERATIONS` (default: 3), `CROSS_PROVIDER_MODELS` (per-provider model map: `codex=o3,gemini=2.5-pro`), `CROSS_PROVIDER_DRY_RUN=1` (show config only).
**Verbose levels**: `CROSS_PROVIDER_VERBOSE=1` (prefix logs), `CROSS_PROVIDER_VERBOSE=2` (structured banners with provider availability, timing, consensus reasoning).
**Auto-rotation**: `CROSS_PROVIDER_COOLDOWN=300` (cooldown seconds after rate limit), `CROSS_PROVIDER_CLAUDE_PROFILES=work,personal` (Claude subscription profile rotation). Rate-limited providers auto-skip with cooldown; Claude profiles rotate through `~/.claude-<name>/` dirs.
**Hook**: `.claude/hooks/cross-provider-bridge.sh` (command type, not prompt/agent — same-provider defeats purpose)
**gwt-ticket**: `--bridge [N]`, `--bridge-providers P`, `--bridge-mode MODE`, `--bridge-verbose`, `--bridge-model M`, `--bridge-models MAP`, `--bridge-timeout S`, `--bridge-log FILE`, `--bridge-dry-run`, `--bridge-cooldown S`, `--bridge-profiles P`
**Testing**: `scripts/test-claude-pipeline.sh` (`--live` for E2E)

### Decision Quality System (DQS)
Multi-perspective plan evaluation. Docs: `docs/decision-quality-system.md`.

**Three paths**: Council (`cpipe --preset council`), Red Team (`CROSS_PROVIDER_MODE=redteam`), First Principles (`CROSS_PROVIDER_MODE=assumptions`).
**Pipeline presets**: `--preset council` (opus→sonnet→opus), `--preset redteam` (opus→sonnet).
**Plan template**: `templates/workflows/plan-review.toml`.

### Documentation Merge Driver
Custom git merge driver for CLAUDE.md and AGENTS.md that prevents conflicts when multiple worktrees append content.

**How it works**: Uses `git merge-file --union` to keep both sides' changes instead of creating conflict markers. Deduplicates identical consecutive lines. Falls back to standard merge for truly irreconcilable changes.
**Files**: `scripts/merge-driver-union.sh` (driver), `.gitattributes` (registration), `scripts/setup.sh` (git config)
**Also**: `auto-merge.sh` enhanced to try union merge for `.md` files before marking as non-additive
**Tests**: `scripts/test-filter.sh merge-driver`

### Recent Updates
<<<<<<< HEAD
- **2026-03-01**: Added Claude Code CLI Reference Guide (`docs/claude-code-cli-reference.md`) with complete CLI commands, flags, permissions, subagent config, and dotfiles integration map
- **2026-03-01**: Added Claude Code Settings best practices ($schema validation, permission rules, sandbox config, attribution suppression, effort level env var)
- **2026-03-01**: Migrated Claude Code from Homebrew cask to native installer (auto-updates, no Node.js dependency, `stable` release channel, `claude doctor` verification, removed legacy wrapper script)
- **2026-03-01**: Replaced custom checkpoints system with entireio/cli (`entire` CLI) — removed 7 custom scripts, updated hooks/Fish wrappers/gwt-ticket, Brewfile integration
- **2026-03-01**: Added Claude Code subagents (15 agent files in .claude/agents/, 12 domain specialists + 3 project-specific, maxTurns/skills/mcpServers from official docs, SubagentStart/SubagentStop hooks, 155-test suite)
||||||| c16409d
=======
- **2026-03-01**: Added union merge driver for CLAUDE.md/AGENTS.md to auto-resolve worktree merge conflicts
>>>>>>> mergeconflict
- **2026-02-28**: Added ClaudeCodeBrowser Firefox browser automation (MCP integration, CORS hardening, ccb Fish function, setup.sh automation)
- **2026-02-28**: Added Claude Code Remote Control setup (enableRemoteControl in ~/.claude.json, cc-rc Fish function, 16-test suite)
- **2026-02-21**: Added Skills Reference Guide (`docs/skills-reference.md`) with ranked marketplace sources, Agent Skills standard, migration guide from commands to skills
- **2026-02-12**: Added OpenClaw AI assistant platform integration (multi-channel inbox, security-hardened config, Fish functions, notification helpers, 42-test suite)
- **2026-02-12**: Enhanced Cross-Provider Bridge with multi-provider support (Gemini, Ollama, DeepSeek, Claude), verbose mode, configurable timeout/logging, per-provider model overrides, gwt-ticket bridge flags
- **2026-02-12**: Added comprehensive hooks integration (PreToolUse bun/bash validation, Notification desktop alerts/logging, PostToolUse DeepWiki context, test suite, docs)
- **2026-02-11**: Added Checkpoints system (session context linked to git commits, orphan branch storage, ckpt CLI)
- **2026-02-11**: Added gwt-doctor agent health check, activated Beads agent memory (phases 3-5)
- **2026-02-09**: Added Gastown agent orchestration patterns (agent-state, witness, merge-queue, triage, phase-gates, workflow templates)
- **2026-02-08**: Added Cross-Provider Reasoning Bridge (Stop hook for correlation-bias mitigation via Codex/OpenCode)
- **2026-02-08**: Added Claude Pipeline multi-model reasoning chains (claude-pipeline/cpipe - opus→sonnet piping)
- **2026-02-08**: Added Beads agent memory integration (steveyegge/beads - git-backed issue tracker for AI agents)
- **2026-02-07**: Added local coding agent integration (OpenCode + Claude Code via Ollama with qwen3-coder)
- **2026-02-05**: Added Self-Hosted LLM infrastructure (Ollama + Open WebUI + Fish functions)
- **2026-02-05**: Added Agentic Ticket Execution System (/todo, /ticket-execute, ralph-loop integration)
- **2026-01-25**: Added Cloudflare DNS configuration to macos-defaults.sh (bypasses UK ISP DNS blocking)
- **2026-01-25**: Added terraform-skill plugin from antonbabenko/terraform-skill for Terraform/OpenTofu development
- **2026-01-23**: Added Clawdbot AI assistant integration for WhatsApp/Telegram interface to Claude
- **2026-01-17**: Added Mobile Coding Setup script for remote development from mobile devices via Mosh + Tailscale
- **2026-01-14**: Added `autoCompactEnabled: false` to setup.sh for automatic context compaction control
- **2025-12-17**: Added 11 Claude Code plugins from anthropics/claude-code marketplace
- **2025-11-01**: Configured Opencode with transparent background using system theme (inherits terminal transparency)
- **2025-10-30**: Added Docker container testing framework for Linux compatibility validation
- **2025-10-30**: Fixed BAT_PAGING error in Fish and Zsh configs (prevents FZF preview file descriptor errors)
- **2025-01-26**: Aligned Fish and Zsh configurations for feature parity
- **2025-01-26**: Removed Powerlevel10k configs in favor of Starship-only setup
- **2025-10-05**: Added Kubernetes manifests directory with documentation requirements
