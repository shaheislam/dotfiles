# Claude Code CLI Reference

> Complete CLI reference for Claude Code, tailored to this dotfiles setup. Based on official documentation at
> [code.claude.com/docs/en/cli-reference](https://code.claude.com/docs/en/cli-reference) and related pages.
> Covers commands, flags, permission modes, subagent configuration, and how they map to our Fish functions and scripts.

## Table of Contents

- [CLI Commands](#cli-commands)
- [CLI Flags](#cli-flags)
- [System Prompt Flags](#system-prompt-flags)
- [Subagent Configuration](#subagent-configuration)
- [Permission Modes](#permission-modes)
- [Permission Rule Syntax](#permission-rule-syntax)
- [Settings Scopes & Precedence](#settings-scopes--precedence)
- [Interactive Mode Reference](#interactive-mode-reference)
- [Skills Configuration](#skills-configuration)
- [Our Dotfiles Integration](#our-dotfiles-integration)
- [Environment Variables](#environment-variables)
- [Patterns & Recipes](#patterns--recipes)

---

## CLI Commands

### Session Management

| Command | Description | Example |
|---------|-------------|---------|
| `claude` | Start interactive session | `claude` |
| `claude "query"` | Start with initial prompt | `claude "explain this project"` |
| `claude -p "query"` | Print mode (SDK), exit after response | `claude -p "explain this function"` |
| `cat file \| claude -p "query"` | Process piped content | `cat logs.txt \| claude -p "explain"` |
| `claude -c` | Continue most recent conversation (cwd-scoped) | `claude -c` |
| `claude -c -p "query"` | Continue via SDK pipe mode | `claude -c -p "check for type errors"` |
| `claude -r "session" "query"` | Resume by ID or name | `claude -r "auth-refactor" "finish PR"` |

### Authentication

| Command | Description | Example |
|---------|-------------|---------|
| `claude auth login` | Sign in (supports `--email`, `--sso`) | `claude auth login --email user@example.com --sso` |
| `claude auth logout` | Sign out | `claude auth logout` |
| `claude auth status` | Show auth status as JSON (`--text` for human-readable) | `claude auth status --text` |

### Administration

| Command | Description | Example |
|---------|-------------|---------|
| `claude update` | Update to latest version | `claude update` |
| `claude agents` | List all configured subagents by source | `claude agents` |
| `claude mcp` | Configure MCP servers | See [MCP docs](https://code.claude.com/docs/en/mcp) |
| `claude remote-control` | Start Remote Control session | `claude remote-control --verbose` |

---

## CLI Flags

### Session Flags

| Flag | Description | Example |
|------|-------------|---------|
| `--continue`, `-c` | Continue most recent conversation | `claude -c` |
| `--resume`, `-r` | Resume by ID/name or show picker | `claude -r auth-refactor` |
| `--fork-session` | Fork when resuming (new session ID) | `claude --resume abc --fork-session` |
| `--from-pr` | Resume sessions linked to a PR | `claude --from-pr 123` |
| `--session-id` | Use specific UUID for conversation | `claude --session-id "550e8400-..."` |
| `--worktree`, `-w` | Start in isolated git worktree | `claude -w feature-auth` |
| `--remote` | Create web session on claude.ai | `claude --remote "fix login bug"` |
| `--teleport` | Resume web session locally | `claude --teleport` |

### Model & Output

| Flag | Description | Example |
|------|-------------|---------|
| `--model` | Set model (alias: `sonnet`, `opus`, `haiku`, or full name) | `claude --model claude-sonnet-4-6` |
| `--print`, `-p` | Print mode (non-interactive) | `claude -p "query"` |
| `--output-format` | Output format: `text`, `json`, `stream-json` | `claude -p --output-format json "query"` |
| `--input-format` | Input format: `text`, `stream-json` | `claude -p --input-format stream-json` |
| `--include-partial-messages` | Include partial streaming events | `claude -p --output-format stream-json --include-partial-messages "query"` |
| `--json-schema` | Get validated JSON matching schema | `claude -p --json-schema '{"type":"object",...}' "query"` |
| `--verbose` | Verbose logging (turn-by-turn output) | `claude --verbose` |
| `--version`, `-v` | Print version | `claude -v` |

### Resource Limits

| Flag | Description | Example |
|------|-------------|---------|
| `--max-turns` | Limit agentic turns (print mode) | `claude -p --max-turns 3 "query"` |
| `--max-budget-usd` | Max API spend before stopping (print mode) | `claude -p --max-budget-usd 5.00 "query"` |
| `--fallback-model` | Auto-fallback when overloaded (print mode) | `claude -p --fallback-model sonnet "query"` |

### Permissions & Security

| Flag | Description | Example |
|------|-------------|---------|
| `--permission-mode` | Set permission mode | `claude --permission-mode plan` |
| `--dangerously-skip-permissions` | Skip all permission prompts | `claude --dangerously-skip-permissions` |
| `--allow-dangerously-skip-permissions` | Enable bypass as option (compose with `--permission-mode`) | `claude --permission-mode plan --allow-dangerously-skip-permissions` |
| `--allowedTools` | Tools allowed without prompting | `claude --allowedTools "Bash(git *)" "Read"` |
| `--disallowedTools` | Tools removed from context entirely | `claude --disallowedTools "Bash(curl *)" "Edit"` |
| `--tools` | Restrict which built-in tools are available | `claude --tools "Bash,Edit,Read"` |
| `--permission-prompt-tool` | MCP tool for permission prompts (non-interactive) | `claude -p --permission-prompt-tool mcp_tool "query"` |

### System Prompt

| Flag | Description | Modes |
|------|-------------|-------|
| `--system-prompt` | **Replace** entire default prompt | Interactive + Print |
| `--system-prompt-file` | **Replace** with file contents | Print only |
| `--append-system-prompt` | **Append** to default prompt | Interactive + Print |
| `--append-system-prompt-file` | **Append** file contents | Print only |

### Working Directories & Configuration

| Flag | Description | Example |
|------|-------------|---------|
| `--add-dir` | Add additional working directories | `claude --add-dir ../apps ../lib` |
| `--mcp-config` | Load MCP servers from JSON file | `claude --mcp-config ./mcp.json` |
| `--strict-mcp-config` | Only use MCP from `--mcp-config` | `claude --strict-mcp-config --mcp-config ./mcp.json` |
| `--settings` | Path to settings JSON file | `claude --settings ./settings.json` |
| `--setting-sources` | Select setting scopes to load | `claude --setting-sources user,project` |
| `--plugin-dir` | Load plugins from directory (session only) | `claude --plugin-dir ./my-plugins` |

### Subagents & Teams

| Flag | Description | Example |
|------|-------------|---------|
| `--agent` | Set agent for session | `claude --agent my-custom-agent` |
| `--agents` | Define subagents via JSON | See [Subagent JSON format](#agents-flag-format) |
| `--teammate-mode` | Agent team display: `auto`, `in-process`, `tmux` | `claude --teammate-mode in-process` |

### Browser & Features

| Flag | Description | Example |
|------|-------------|---------|
| `--chrome` | Enable Chrome browser integration | `claude --chrome` |
| `--no-chrome` | Disable Chrome integration | `claude --no-chrome` |
| `--ide` | Auto-connect to IDE on startup | `claude --ide` |
| `--disable-slash-commands` | Disable all skills/slash commands | `claude --disable-slash-commands` |

### Session Lifecycle

| Flag | Description | Example |
|------|-------------|---------|
| `--init` | Run init hooks + start interactive | `claude --init` |
| `--init-only` | Run init hooks + exit | `claude --init-only` |
| `--maintenance` | Run maintenance hooks + exit | `claude --maintenance` |
| `--no-session-persistence` | Don't save sessions (print mode) | `claude -p --no-session-persistence "query"` |

### Debugging

| Flag | Description | Example |
|------|-------------|---------|
| `--debug` | Debug mode with category filter | `claude --debug "api,hooks"` |
| `--betas` | Beta headers for API (API key users) | `claude --betas interleaved-thinking` |

---

## System Prompt Flags

Four flags control system prompt customization with distinct behaviors:

| Flag | Behavior | Modes | Use Case |
|------|----------|-------|----------|
| `--system-prompt` | **Replaces** entire default prompt | Interactive + Print | Complete control — removes all default Claude Code instructions |
| `--system-prompt-file` | **Replaces** with file contents | Print only | Team-shared prompts via version-controlled files |
| `--append-system-prompt` | **Appends** to default prompt | Interactive + Print | Add rules while keeping Claude Code capabilities (safest) |
| `--append-system-prompt-file` | **Appends** file contents | Print only | Version-controlled additions |

**Mutual exclusivity**: `--system-prompt` and `--system-prompt-file` cannot be used together. The append flags can combine with either replacement flag.

**Recommendation**: Use `--append-system-prompt` for most use cases. Only use `--system-prompt` when you need full prompt control.

**Our usage**: `claude-pipeline.fish` uses `--system-prompt` to set the reasoning/execution prompts for each pipeline stage:

```fish
claude -p --model $model --system-prompt "You are a reasoning specialist..."
```

---

## Subagent Configuration

### Agents Flag Format

The `--agents` flag accepts JSON defining one or more subagents:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

| Field | Required | Description |
|-------|----------|-------------|
| `description` | Yes | When to invoke the subagent |
| `prompt` | Yes | System prompt guiding behavior |
| `tools` | No | Tool allowlist; inherits all if omitted |
| `disallowedTools` | No | Tool denylist |
| `model` | No | `sonnet`, `opus`, `haiku`, or `inherit` (default) |
| `skills` | No | Skills to preload into context |
| `mcpServers` | No | MCP servers for this subagent |
| `maxTurns` | No | Max agentic turns |

### Subagent File Format

Subagent `.md` files with YAML frontmatter, stored in:

| Location | Scope | Priority |
|----------|-------|----------|
| `--agents` CLI flag | Session only | 1 (highest) |
| `.claude/agents/` | Project | 2 |
| `~/.claude/agents/` | All projects | 3 |
| Plugin `agents/` | Where plugin enabled | 4 (lowest) |

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
permissionMode: default
memory: user
background: false
isolation: worktree
---

You are a code reviewer. Analyze code and provide feedback.
```

### Additional Subagent Fields

| Field | Description |
|-------|-------------|
| `permissionMode` | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `memory` | Persistent memory scope: `user`, `project`, `local` |
| `background` | Always run as background task |
| `isolation` | `worktree` for isolated git worktree |
| `hooks` | Lifecycle hooks scoped to subagent |
| `skills` | Skills to inject at startup |

### Built-in Subagents

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| **Explore** | Haiku | Read-only | Fast codebase search, file discovery |
| **Plan** | Inherit | Read-only | Research for plan mode |
| **general-purpose** | Inherit | All | Complex multi-step tasks |
| **Bash** | Inherit | Bash | Terminal commands in separate context |
| **statusline-setup** | Sonnet | Read, Edit | Configure status line |
| **Claude Code Guide** | Haiku | Read-only | Answer questions about Claude Code |

### Controlling Subagent Spawning

Restrict which subagents an agent can spawn via `tools` field:

```yaml
tools: Agent(worker, researcher), Read, Bash
# Only 'worker' and 'researcher' subagents can be spawned
```

Disable specific subagents via permissions:

```json
{
  "permissions": {
    "deny": ["Agent(Explore)", "Agent(my-custom-agent)"]
  }
}
```

---

## Permission Modes

| Mode | Description | Behavior |
|------|-------------|----------|
| `default` | Standard | Prompts for permission on first tool use |
| `acceptEdits` | Auto-accept edits | File modifications auto-approved for session |
| `plan` | Plan mode | Read-only analysis, no file modifications |
| `dontAsk` | Auto-deny | Denies unless pre-approved via permissions |
| `bypassPermissions` | Skip all | No permission checks (containers/VMs only) |

Set via: `claude --permission-mode plan` or `defaultMode` in settings.

---

## Permission Rule Syntax

Rules follow the format `Tool` or `Tool(specifier)`:

### Basic Patterns

| Rule | Matches |
|------|---------|
| `Bash` | All bash commands |
| `Bash(npm run *)` | Commands starting with `npm run ` |
| `Bash(* --version)` | Commands ending with ` --version` |
| `Read(./.env)` | Reading `.env` in project root |
| `WebFetch(domain:example.com)` | Fetches to example.com |
| `mcp__puppeteer__*` | All tools from puppeteer MCP server |
| `Agent(Explore)` | The Explore subagent |
| `Skill(deploy *)` | The deploy skill with any args |

### Read/Edit Path Patterns

Follows gitignore spec with four path types:

| Pattern | Meaning | Example |
|---------|---------|---------|
| `//path` | Absolute from filesystem root | `Read(//Users/alice/secrets/**)` |
| `~/path` | From home directory | `Read(~/Documents/*.pdf)` |
| `/path` | Relative to project root | `Edit(/src/**/*.ts)` |
| `path` or `./path` | Relative to current directory | `Read(*.env)` |

**Key**: `*` matches single directory; `**` matches recursively.

### Evaluation Order

Rules evaluate: **deny -> ask -> allow**. First matching rule wins.

### Example Permission Config

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git commit *)",
      "Read"
    ],
    "ask": [
      "Bash(git push *)",
      "Edit(./src/**)"
    ],
    "deny": [
      "Read(./.env*)",
      "Read(./secrets/**)",
      "Bash(curl *)",
      "Bash(rm -rf *)"
    ]
  }
}
```

---

## Settings Scopes & Precedence

### Scope Hierarchy (highest to lowest)

1. **Managed** — IT/DevOps enforced (cannot override)
2. **Command line** — session overrides via flags
3. **Local** — `.claude/settings.local.json` (git-ignored, per-machine)
4. **Project** — `.claude/settings.json` (team-shared, committed)
5. **User** — `~/.claude/settings.json` (personal global)

### Key Setting Files

| File | Purpose | Commit? |
|------|---------|---------|
| `~/.claude/settings.json` | Personal global preferences | No |
| `.claude/settings.json` | Team settings, permissions | Yes |
| `.claude/settings.local.json` | Machine-specific overrides, secrets | No (`.gitignore`) |
| `~/.claude.json` | MCP servers, global config | No |
| `.mcp.json` | Project MCP servers | Yes |

### Schema Validation

Add to settings files for IDE autocomplete:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

---

## Interactive Mode Reference

### Key Shortcuts

| Shortcut | Description |
|----------|-------------|
| `Ctrl+C` | Cancel input/generation |
| `Ctrl+D` | Exit session |
| `Ctrl+G` | Open prompt in text editor |
| `Ctrl+L` | Clear terminal screen |
| `Ctrl+O` | Toggle verbose output |
| `Ctrl+R` | Reverse search history |
| `Ctrl+V` | Paste image from clipboard |
| `Ctrl+B` | Background running tasks (tmux: press twice) |
| `Ctrl+T` | Toggle task list |
| `Ctrl+F` | Kill all background agents (press twice to confirm) |
| `Shift+Tab` | Toggle permission modes |
| `Option+P` | Switch model |
| `Option+T` | Toggle extended thinking |
| `Esc Esc` | Rewind/summarize |

### Quick Prefixes

| Prefix | Action |
|--------|--------|
| `/` | Invoke skill or built-in command |
| `!` | Run bash command directly |
| `@` | File path autocomplete |

### Built-in Commands

| Command | Purpose |
|---------|---------|
| `/clear` | Clear conversation |
| `/compact [instructions]` | Compact with optional focus |
| `/config` | Settings interface |
| `/context` | Visualize context usage grid |
| `/cost` | Token usage statistics |
| `/debug [desc]` | Session debugging |
| `/doctor` | Installation health check |
| `/export [file]` | Export conversation |
| `/memory` | Edit CLAUDE.md files |
| `/model` | Select/change model |
| `/permissions` | View/manage permissions |
| `/plan` | Enter plan mode |
| `/rename [name]` | Rename session |
| `/resume [session]` | Resume conversation |
| `/rewind` | Rewind conversation/code |
| `/stats` | Usage visualization |
| `/status` | Version, model, account info |
| `/statusline` | Configure status line |
| `/copy` | Copy last response |
| `/tasks` | Manage background tasks |
| `/theme` | Change color theme |
| `/todos` | List TODO items |
| `/usage` | Plan usage limits |
| `/vim` | Toggle vim editing mode |
| `/batch <instruction>` | Parallel large-scale changes across codebase |
| `/simplify` | Review recent changes for quality/reuse/efficiency |

### Multiline Input

| Method | Shortcut |
|--------|----------|
| Quick escape | `\` + `Enter` |
| macOS | `Option+Enter` |
| Shift+Enter | Works in iTerm2, WezTerm, Ghostty, Kitty |
| Control sequence | `Ctrl+J` |

---

## Skills Configuration

### Skill File Format

```yaml
---
name: my-skill
description: What this skill does and when to use it
argument-hint: "[filename] [--flag]"
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Grep, Glob
model: sonnet
context: fork
agent: Explore
---

Skill instructions in markdown...
Use $ARGUMENTS for user input, $0/$1 for positional args.
Use !`command` for dynamic context injection.
```

### Skill Locations

| Location | Scope |
|----------|-------|
| `~/.claude/skills/<name>/SKILL.md` | Personal (all projects) |
| `.claude/skills/<name>/SKILL.md` | Project (committed) |
| `<plugin>/skills/<name>/SKILL.md` | Plugin-scoped |

### Invocation Control

| Setting | You invoke | Claude invokes |
|---------|-----------|----------------|
| Default | Yes | Yes |
| `disable-model-invocation: true` | Yes | No |
| `user-invocable: false` | No | Yes |

### Key Substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All args passed when invoking |
| `$ARGUMENTS[N]` / `$N` | Specific arg by index |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `!`command`` | Dynamic shell command output (preprocessing) |

---

## Our Dotfiles Integration

### Fish Functions Using Claude CLI

| Function | File | Claude Flags Used | Purpose |
|----------|------|-------------------|---------|
| `claude-pipeline` / `cpipe` | `.config/fish/functions/claude-pipeline.fish` | `-p`, `--model`, `--system-prompt`, `--output-format stream-json`, `--input-format stream-json` | Multi-model reasoning chains |
| `claude-sub` / `csub` | `.config/fish/functions/claude-sub.fish` | `CLAUDE_CONFIG_DIR` env var | Subscription profile switching |
| `claude-local` | `.config/fish/functions/claude-local.fish` | `--model`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` env vars | Local Ollama integration |
| `cc-rc` | `.config/fish/functions/cc-rc.fish` | `remote-control`, `--verbose`, `--sandbox`, `auth status --text` | Remote Control management |
| `cc-lsp` | `.config/fish/functions/cc-lsp.fish` | `plugin marketplace add`, `plugin install`, `plugin marketplace list` | LSP plugin management |
| `gwt-claude` / `gwtc` | `.config/fish/functions/gwt-claude.fish` | Via `devcon claude` with `CLAUDE_CONFIG_DIR` | Claude in worktree devcontainer |
| `gwt-ticket` / `gwtt` | `.config/fish/functions/gwt-ticket.fish` | Via ralph-loop in devcontainer | Autonomous ticket execution |

### Setup Script (`scripts/setup.sh`)

MCP server configuration:
```bash
claude mcp add --scope user context7 bunx @upstash/context7-mcp
claude mcp add --scope user steampipe npx @turbot/steampipe-mcp ...
claude mcp add --scope user playwright bunx @playwright/mcp@latest
claude mcp add --scope user --transport sse deepwiki https://mcp.deepwiki.com/sse
```

Plugin installation:
```bash
claude plugin marketplace add anthropics/claude-code
claude plugin marketplace add obra/superpowers-marketplace
claude plugin marketplace add steveyegge/beads
claude plugin marketplace add boostvolt/claude-code-lsps
claude plugin install code-review@claude-code-plugins
# ... (14 plugins total)
```

### Flags NOT Currently Used

These official flags are available but not yet integrated in our dotfiles:

| Flag | Potential Use |
|------|--------------|
| `--add-dir` | Multi-repo projects without worktrees |
| `--worktree` | Native worktree creation (we use `gwt-*` functions instead) |
| `--agent` | Session-level agent override |
| `--agents` | Dynamic subagent definitions for scripting |
| `--mcp-config` | Per-session MCP overrides |
| `--json-schema` | Structured output for automation scripts |
| `--max-turns` | Guard against runaway agents |
| `--max-budget-usd` | Cost control for background agents |
| `--fallback-model` | Graceful degradation on overload |
| `--append-system-prompt` | Per-invocation rules for `gwt-ticket` |
| `--no-session-persistence` | Ephemeral CI/CD runs |
| `--strict-mcp-config` | Locked-down MCP for containers |
| `--setting-sources` | Selective settings loading |

---

## Environment Variables

### Core Variables

| Variable | Purpose | Our Usage |
|----------|---------|-----------|
| `CLAUDE_CONFIG_DIR` | Override config directory path | `claude-sub.fish` for subscription profiles (`~/.claude-<name>/`) |
| `ANTHROPIC_API_KEY` | API authentication | `claude-local.fish` (set to `ollama` for local) |
| `ANTHROPIC_BASE_URL` | Custom API endpoint | `claude-local.fish` (`http://localhost:11434`) |
| `ANTHROPIC_MODEL` | Model override | `claude-local.fish` for Ollama models |

### Feature Flags

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enable OpenTelemetry | Off |
| `CLAUDE_CODE_SHELL` | Override shell detection | Auto-detected |
| `CLAUDE_CODE_TMPDIR` | Custom temp directory | System temp |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | Disable background tasks | `0` |
| `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` | Prompt suggestions | `true` |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Enable agent teams | Off |
| `CLAUDE_CODE_TASK_LIST_ID` | Named shared task list | None |
| `DISABLE_TELEMETRY` | Opt out of usage tracking | Off |
| `DISABLE_AUTOUPDATER` | Disable auto-updates | Off |
| `FORCE_AUTOUPDATE_PLUGINS` | Force plugin auto-update | `1` (in our `config.fish`) |
| `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | Load CLAUDE.md from `--add-dir` dirs | `1` (in our `config.fish`) |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Trigger compaction earlier (%) | 95 |
| `SLASH_COMMAND_TOOL_CHAR_BUDGET` | Skill description budget | 2% of context |

### Bash Tool Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `BASH_MAX_TIMEOUT_MS` | Max bash command timeout | 120000 |
| `BASH_MAX_OUTPUT_LENGTH` | Max output length | 50000 |

---

## Patterns & Recipes

### Pipeline Mode (Multi-Model Reasoning)

Our `claude-pipeline` / `cpipe` function chains models:

```fish
# Default: opus reasons, sonnet executes
cpipe "analyze this architecture"

# Presets
cpipe --preset review "review this PR"      # opus -> sonnet -> haiku
cpipe --preset cheap "quick question"        # sonnet -> haiku
cpipe --preset local "offline analysis"      # ollama -> sonnet
cpipe --preset council "evaluate this plan"  # opus -> sonnet -> opus
```

Under the hood, each stage uses:
```bash
claude -p --model $model --system-prompt "$stage_prompt" --output-format stream-json
```

### Subscription Profile Switching

```fish
# List profiles
csub list

# Switch profile
csub work
csub personal

# Launch claude in profile
env CLAUDE_CONFIG_DIR=~/.claude-work/ claude
```

### Local LLM Fallback

```fish
# Use local Ollama models via claude CLI
claude-local                           # Default: qwen3-coder
claude-local --model llama3.1:8b       # Specific model

# Internally sets:
# ANTHROPIC_BASE_URL=http://localhost:11434
# ANTHROPIC_API_KEY=ollama
```

### Remote Control

```fish
cc-rc start          # Start remote control session
cc-rc status         # Check if RC is running
cc-rc tmux           # Start in dedicated tmux window
cc-rc enable         # Enable globally in ~/.claude.json
```

### Automation with Print Mode

```bash
# Structured output for scripting
claude -p --output-format json "list all TODO items" | jq '.result'

# Piped analysis
git diff HEAD~5 | claude -p "summarize these changes"

# Cost-controlled background work
claude -p --max-turns 10 --max-budget-usd 2.00 "refactor auth module"

# Fallback on overload
claude -p --fallback-model sonnet "complex analysis query"
```

### Permission Hardening for CI/CD

```bash
# Read-only analysis in CI
claude --permission-mode plan -p "review this PR for security issues"

# Locked-down execution with specific tools
claude --tools "Bash,Read" --allowedTools "Bash(npm test *)" -p "run tests"

# Container/VM mode (skip all prompts)
claude --dangerously-skip-permissions -p "deploy to staging"
```

### Dynamic Subagents for Scripting

```bash
# One-off code review agent
claude --agents '{
  "reviewer": {
    "description": "Expert code reviewer",
    "prompt": "Review for security, performance, and best practices",
    "tools": ["Read", "Grep", "Glob"],
    "model": "sonnet"
  }
}' -p "review the recent changes"
```

### Sandbox Configuration

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "filesystem": {
      "allowWrite": ["//tmp/build"],
      "denyRead": ["~/.aws/credentials"]
    },
    "network": {
      "allowedDomains": ["github.com", "*.npmjs.org"]
    }
  }
}
```

---

## Integration Opportunities

Flags and features from official docs not yet leveraged in our setup:

### High Priority

1. **`--max-turns` / `--max-budget-usd`** for `gwt-ticket` — guard against runaway background agents
2. **`--fallback-model`** for `claude-pipeline` — graceful degradation when primary model is overloaded
3. **`--append-system-prompt`** for `gwt-ticket` — inject ticket context without replacing system prompt
4. **`--json-schema`** for automation scripts — structured output for `ticket-execute`, `agent-state`

### Medium Priority

5. **`--agents` flag** for `gwt-parallel` — define task-specific subagents per worktree
6. **`--strict-mcp-config`** for devcontainers — locked-down MCP in containerized environments
7. **`--no-session-persistence`** for ephemeral CI/CD pipeline runs
8. **Subagent `memory: user`** — persistent cross-session learning for our plugin agents
9. **Subagent `isolation: worktree`** — native worktree isolation without our `gwt-*` wrapper

### Lower Priority

10. **`--setting-sources`** — selective settings loading for testing
11. **`--mcp-config`** — per-session MCP overrides for specialized tasks
12. **`--from-pr`** — resume sessions linked to PRs for review workflows
13. **Sandbox `network.allowedDomains`** — domain-level network restrictions for security

---

## See Also

- [Claude Code Hooks Reference](claude-code-hooks.md) — hook events, types, our setup
- [Skills Reference](skills-reference.md) — skill sources, format, migration guide
- [Claude Code LSP Integration](claude-code-lsp.md) — LSP servers for Claude Code
- [Claude Pipeline](claude-pipeline.md) — multi-model reasoning chains
- [Neovim-Claude Bridge](nvim-claude-bridge.md) — editor state awareness
- [Official CLI Reference](https://code.claude.com/docs/en/cli-reference) — upstream source
- [Official Settings](https://code.claude.com/docs/en/settings) — configuration reference
- [Official Permissions](https://code.claude.com/docs/en/permissions) — permission system
- [Official Subagents](https://code.claude.com/docs/en/sub-agents) — subagent documentation
- [Official Skills](https://code.claude.com/docs/en/skills) — skills documentation
