# Claude Code CLI Reference

> Complete CLI reference for Claude Code, tailored to this dotfiles setup. Based on official documentation at
> [code.claude.com/docs/en/cli-reference](https://code.claude.com/docs/en/cli-reference) and related pages.
> Covers commands, flags, permission modes, subagent configuration, hooks, model config, MCP, agent teams,
> common workflows, and how they map to our Fish functions and scripts.

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
- [Common Workflows](#common-workflows)
- [Model Configuration](#model-configuration)
- [Hooks Reference](#hooks-reference)
- [MCP Configuration](#mcp-configuration)
- [Agent Teams](#agent-teams)
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
| `claude mcp` | Configure MCP servers | See [MCP Configuration](#mcp-configuration) |
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
| `--name`, `-n` | Set display name for session (shown in `/resume` and terminal title) | `claude --name auth-refactor` |
| `--worktree`, `-w` | Start in isolated git worktree | `claude -w feature-auth` |
| `--remote` | Create web session on claude.ai | `claude --remote "fix login bug"` |
| `--teleport` | Resume web session locally | `claude --teleport` |

### Model & Output

| Flag | Description | Example |
|------|-------------|---------|
| `--model` | Set model (alias: `sonnet`, `opus`, `haiku`, or full name) | `claude --model claude-sonnet-4-6` |
| `--effort` | Effort level: `low`, `medium`, `high`, `max` (max = Opus 4.6 only, 1M context) | `claude --effort max` |
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
| `/hooks` | Interactive hooks manager |
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
| `` !`command` `` | Dynamic shell command output (preprocessing) |

---

## Common Workflows

### Plan Mode

Plan mode restricts Claude to read-only tools for analysis before implementation:

| Method | Description |
|--------|-------------|
| `claude --permission-mode plan` | Start in plan mode |
| `/plan` | Enter plan mode during session |
| `Shift+Tab` | Toggle between modes interactively |

In plan mode, Claude can read files, search, and analyze but cannot write, edit, or execute commands. Use it to understand a codebase before making changes.

**Our usage**: Our `ORCHESTRATOR.md` auto-activates plan mode for complex analysis tasks.

### Worktrees

Start Claude in an isolated git worktree for parallel development:

```bash
claude --worktree feature-auth     # Named worktree
claude -w                          # Auto-generated name (e.g. bold-oak-a3f2)
```

The worktree is created in `.claude/worktrees/` with a new branch based on HEAD. On exit, you're prompted to keep or remove it.

**Our usage**: We use `gwt-*` Fish functions (`gwt-dev`, `gwt-claude`, `gwt-ticket`) which wrap worktree creation with devcontainer integration, subscription profiles, and ralph-loop orchestration. The native `--worktree` flag is a simpler alternative for quick isolated work.

### Piping & Unix-Style Usage

Claude integrates with Unix pipes for non-interactive automation:

```bash
# Pipe content for analysis
cat error.log | claude -p "what went wrong?"
git diff HEAD~5 | claude -p "summarize changes"

# Chain with other tools
claude -p --output-format json "list API endpoints" | jq '.result'

# Multi-step pipelines
cat spec.md | claude -p "generate test cases" | claude -p "implement these tests"
```

### Session Management

Resume, continue, and fork sessions:

| Action | Command | Notes |
|--------|---------|-------|
| Continue last | `claude -c` | Most recent conversation in current directory |
| Resume by name | `claude -r "session-name"` | Session picker if no match |
| Resume by ID | `claude -r abc123` | Exact session UUID |
| Fork session | `claude -r abc123 --fork-session` | New ID, same history |
| Rename | `/rename my-feature` | Inside interactive session |

Sessions are scoped per directory. Use `--session-id` for deterministic IDs in automation.

### Images

Claude can process images in interactive mode:

| Method | How |
|--------|-----|
| Drag and drop | Drag image file into terminal |
| Clipboard | `Ctrl+V` to paste |
| File path | Use `@` prefix: `@screenshot.png` |
| Piped | `cat image.png \| claude -p "describe this"` |

### @ File References

Reference files and directories directly in prompts:

```
@src/auth/login.ts    # Single file
@src/components/      # Entire directory
@package.json         # Specific config
```

Tab completion works with `@` prefix for file discovery.

### Notifications via Hooks

Claude sends notifications at key points (permission prompts, idle state, auth). Use `Notification` hooks to route these to desktop alerts, Slack, or logging systems.

**Our usage**: `.claude/hooks/macos_notification.py` sends macOS desktop alerts. `.claude/hooks/log-notification.sh` writes audit logs.

### Extended Thinking

Toggle extended thinking for deeper reasoning:

| Control | Method |
|---------|--------|
| Toggle | `Option+T` during session |
| Effort level | Settings: `"effortLevel": "low"`, `"medium"`, or `"high"` |
| Env override | `CLAUDE_CODE_EFFORT_LEVEL=high` |
| Budget | `MAX_THINKING_TOKENS` env var |
| Disable adaptive | `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` |

Effort levels control how much reasoning Claude applies. `high` uses maximum thinking budget, `low` minimizes it. The default adapts based on task complexity.

**Our usage**: Our `--think`, `--think-hard`, and `--ultrathink` flags in `FLAGS.md` map to increasing effort levels.

---

## Model Configuration

### Model Aliases

Use short aliases instead of full model names:

| Alias | Resolves To | Notes |
|-------|-------------|-------|
| `default` | Current default model | Usually latest Sonnet |
| `sonnet` | `claude-sonnet-4-6` | Latest Sonnet |
| `opus` | `claude-opus-4-6` | Latest Opus |
| `haiku` | `claude-haiku-4-5-20251001` | Latest Haiku |
| `sonnet[1m]` | Sonnet with 1M context | Extended context window |
| `opusplan` | Opus for planning, Sonnet for execution | Auto-switches per phase |

```bash
claude --model opus "complex analysis"
claude --model sonnet "quick task"
claude --model haiku "simple question"
```

### The `opusplan` Mode

`opusplan` uses Opus during plan mode (read-only analysis) and automatically switches to Sonnet for execution. Access via `/model opusplan` in interactive mode.

**Our usage**: `claude-pipeline.fish` implements a similar pattern with `--preset council` (opus -> sonnet -> opus).

### Effort Levels

Control reasoning depth via settings or environment:

| Level | Behavior | Availability |
|-------|----------|--------------|
| `low` | Minimal thinking, fastest responses | env var, settings, `/effort` |
| `medium` | Balanced reasoning (default) | env var, settings, `/effort` |
| `high` | Maximum thinking budget, deepest analysis | env var, settings, `/effort` |
| `max` | Maximum capability with deepest reasoning (Opus 4.6 only) | env var, `/effort`, `--effort` (session-scoped, not in settings) |
| `auto` | Reset to model default | env var, `/effort` |

Set in settings: `"effortLevel": "high"` or via `CLAUDE_CODE_EFFORT_LEVEL`. Note: settings key only supports `low`/`medium`/`high`; the env var also supports `max` and `auto`.

**Display quirk**: Claude Code normalizes `max` → `high` in the status bar and internal env var. Verify `max` is active by checking the model ID suffix `[1m]` (1M context = max effort). The `--effort max` flag and `CLAUDE_CODE_EFFORT_LEVEL=max` env var both work correctly despite the display.

### 1M Context Window

`sonnet[1m]` enables a 1,000,000-token context window for large codebases. Disable with `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`.

### Restrict Available Models

Use `availableModels` in settings to limit which models users can select:

```json
{
  "availableModels": ["claude-sonnet-4-6", "claude-haiku-4-5-20251001"]
}
```

### Prompt Caching

Control prompt caching with environment variables:

| Variable | Effect |
|----------|--------|
| `DISABLE_PROMPT_CACHING` | Disable all caching |
| `DISABLE_PROMPT_CACHING_HAIKU` | Disable for Haiku only |
| `DISABLE_PROMPT_CACHING_SONNET` | Disable for Sonnet only |
| `DISABLE_PROMPT_CACHING_OPUS` | Disable for Opus only |

### Model Override Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Override which model "opus" resolves to |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Override which model "sonnet" resolves to |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Override which model "haiku" resolves to |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Force all subagents to use a specific model |

---

## Hooks Reference

Hooks are lifecycle callbacks that run at specific points during Claude Code operation. They enable deterministic control over behavior without modifying Claude's AI instructions.

### Hook Types

| Type | Description | Blocking? |
|------|-------------|-----------|
| `command` | Shell command receiving JSON via stdin | Yes (exit code 2) |
| `http` | HTTP POST to URL with JSON body | Yes (via JSON response) |
| `prompt` | LLM evaluates with yes/no decision | Yes (`ok: false`) |
| `agent` | Multi-turn subagent with tool access | Yes (`ok: false`) |

### Hook Events

17 events covering the full session lifecycle:

| Event | Matcher | Can Block? | Description |
|-------|---------|------------|-------------|
| `SessionStart` | `startup\|resume\|clear\|compact` | No | Session begins or resumes |
| `UserPromptSubmit` | — | Yes | User submits a prompt |
| `PreToolUse` | Tool name | Yes | Before tool execution |
| `PermissionRequest` | Tool name | Yes | Permission dialog shown |
| `PostToolUse` | Tool name | No (feedback) | After successful tool execution |
| `PostToolUseFailure` | Tool name | No (feedback) | After tool failure |
| `Notification` | `permission_prompt\|idle_prompt\|auth_success\|elicitation_dialog` | No | Notification sent |
| `SubagentStart` | Agent type | No (inject context) | Subagent spawned |
| `SubagentStop` | Agent type | Yes | Subagent finished |
| `Stop` | — | Yes | Main agent finished |
| `TeammateIdle` | — | Yes (exit code 2) | Teammate about to idle |
| `TaskCompleted` | — | Yes (exit code 2) | Task marked complete |
| `ConfigChange` | `user_settings\|project_settings\|local_settings\|policy_settings\|skills` | Yes (except policy) | Config file changed |
| `WorktreeCreate` | — | Yes (non-zero exit) | Worktree being created |
| `WorktreeRemove` | — | No | Worktree being removed |
| `PreCompact` | `manual\|auto` | No | Before compaction |
| `SessionEnd` | Exit reason | No | Session ending |

### Hook Configuration

Hooks are defined in settings files under the `"hooks"` key:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/validate-bash.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Common Fields

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | `command`, `http`, `prompt`, or `agent` |
| `timeout` | No | Seconds before timeout (default: 600 for command, 30 for prompt, 60 for agent) |
| `statusMessage` | No | Message shown during execution |
| `once` | No | If true, only runs once per session (useful for skills) |
| `async` | No | If true, runs in background (command type only) |

### Matcher Patterns

Matchers use regex matching against the event-specific value:

- **Tool events**: Match on tool name (`Bash`, `Write\|Edit`, `mcp__context7__.*`)
- **SessionStart**: Match on source (`startup`, `resume`, `clear`, `compact`)
- **Notification**: Match on type (`permission_prompt`, `idle_prompt`)
- **ConfigChange**: Match on source (`user_settings`, `project_settings`)
- **PreCompact**: Match on trigger (`manual`, `auto`)

MCP tools use the format `mcp__<server>__<tool>` (e.g., `mcp__context7__get-library-docs`).

### Exit Code Behavior

| Exit Code | Meaning |
|-----------|---------|
| `0` | Success — action proceeds. Stdout parsed for JSON output |
| `2` | Blocking error — action prevented. Stderr fed to Claude |
| Other | Non-blocking error — logged, execution continues |

### JSON Output Fields

On exit 0, hooks can return JSON to stdout for fine-grained control:

| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | `false` stops Claude entirely |
| `stopReason` | — | Message to user when `continue` is false |
| `suppressOutput` | `false` | Hide stdout from verbose mode |
| `systemMessage` | — | Warning message shown to user |
| `decision` | — | `"block"` to prevent action (PostToolUse, Stop, etc.) |
| `reason` | — | Explanation when blocking |

### PreToolUse Decision Control

PreToolUse uses `hookSpecificOutput` for richer control:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "Explanation",
    "updatedInput": { "field": "modified value" },
    "additionalContext": "Extra context for Claude"
  }
}
```

### PermissionRequest Decision Control

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow|deny",
      "updatedInput": { "command": "safer-command" },
      "updatedPermissions": [{ "type": "toolAlwaysAllow", "tool": "Bash(npm *)" }],
      "message": "Why denied (deny only)"
    }
  }
}
```

### SessionStart Environment Variables

SessionStart hooks can persist env vars via `CLAUDE_ENV_FILE`:

```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

### Hook Scopes

| Source | Location | Priority |
|--------|----------|----------|
| User | `~/.claude/settings.json` | Global |
| Project | `.claude/settings.json` | Team-shared |
| Local | `.claude/settings.local.json` | Machine-specific |
| Plugin | `hooks/hooks.json` in plugin | Read-only |
| Skill/Agent | YAML frontmatter `hooks:` | Component lifetime |

### Hook Management

- `/hooks` menu: View, add, delete hooks interactively
- `disableAllHooks: true` in settings: Temporarily disable all hooks
- Hooks snapshot at startup — mid-session changes require review in `/hooks`
- `claude --debug "hooks"`: Debug hook execution

### Prompt/Agent Hook Events

Events supporting all 4 hook types (`command`, `http`, `prompt`, `agent`):
`PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `PreToolUse`, `Stop`, `SubagentStop`, `TaskCompleted`, `UserPromptSubmit`

Events supporting only `command` hooks:
`ConfigChange`, `Notification`, `PreCompact`, `SessionEnd`, `SessionStart`, `SubagentStart`, `TeammateIdle`, `WorktreeCreate`, `WorktreeRemove`

### Our Hooks Setup

See [Claude Code Hooks Reference](claude-code-hooks.md) for our complete hook configuration. Key hooks:

| Event | Hook | Purpose |
|-------|------|---------|
| SessionStart | `fix-hookify-imports.sh`, `bd prime`, `lsp-status.sh` | Plugin fixes, Beads memory, LSP context |
| PreToolUse (Bash) | `use_bun.py`, `validate-bash.py` | Bun enforcement, dangerous command blocking |
| PostToolUse (Read) | `deepwiki-context.py` | Language-aware DeepWiki suggestions |
| PreCompact | `bd prime` | Beads workflow context |
| Notification | `macos_notification.py`, `log-notification.sh` | Desktop alerts, audit logging |
| UserPromptSubmit | `checkpoint-pre-prompt.sh`, `nvim-bridge.sh` | Checkpoints, Neovim state |
| Stop | `checkpoint-capture.sh`, `cross-provider-bridge.sh` | Checkpoints, cross-provider review |

---

## MCP Configuration

### MCP Server Scopes

| Scope | Config Location | Shared? |
|-------|----------------|---------|
| **Local** (project) | `.mcp.json` in project root | Yes (committed) |
| **Project** | `.claude/settings.json` → `mcpServers` | Yes |
| **User** | `~/.claude/settings.json` → `mcpServers` | No |

### Adding MCP Servers

```bash
# stdio transport (most common)
claude mcp add --scope user context7 bunx @upstash/context7-mcp

# SSE transport
claude mcp add --scope user --transport sse deepwiki https://mcp.deepwiki.com/sse

# HTTP transport
claude mcp add --scope user --transport http myserver https://api.example.com/mcp

# Import from Claude Desktop
claude mcp add-from-claude-desktop
```

### MCP Server Management

| Command | Description |
|---------|-------------|
| `claude mcp add` | Add server (stdio/sse/http) |
| `claude mcp remove` | Remove server |
| `claude mcp list` | List configured servers |
| `claude mcp add-from-claude-desktop` | Import Desktop config |
| `claude mcp serve` | Run Claude Code as an MCP server |

### OAuth 2.0 Authentication

For MCP servers requiring OAuth:

```bash
claude mcp add --transport http myserver https://api.example.com/mcp \
  --client-id "my-client-id" \
  --client-secret "my-client-secret" \
  --callback-port 8080
```

### `.mcp.json` Project Config

Project-level MCP config with environment variable expansion:

```json
{
  "mcpServers": {
    "myserver": {
      "command": "npx",
      "args": ["-y", "my-mcp-server"],
      "env": {
        "API_KEY": "${API_KEY}",
        "PORT": "${PORT:-3000}"
      }
    }
  }
}
```

Environment variables support `${VAR:-default}` syntax for fallback values.

### Tool Search

Control deferred tool loading for MCP servers with many tools:

| Setting | Behavior |
|---------|----------|
| `ENABLE_TOOL_SEARCH=auto` | Auto-defer servers with >10 tools (default) |
| `ENABLE_TOOL_SEARCH=auto:N` | Auto-defer at N tools threshold |
| `ENABLE_TOOL_SEARCH=true` | Defer all MCP tools |
| `ENABLE_TOOL_SEARCH=false` | Load all tools immediately |

Deferred tools must be discovered via `ToolSearch` before use.

### Managed MCP

Enterprise-managed MCP servers via `managed-mcp.json`:

| Platform | Location |
|----------|----------|
| macOS | `/Library/Application Support/ClaudeCode/managed-mcp.json` |
| Linux | `/etc/claude-code/managed-mcp.json` |

Managed servers cannot be overridden by user settings.

### MCP Allowlists/Denylists

Control which MCP servers are permitted:

```json
{
  "allowedMcpServers": ["context7", "playwright"],
  "deniedMcpServers": ["untrusted-server"]
}
```

Matching works against `serverName`, `serverCommand`, and `serverUrl`.

### Claude Code as MCP Server

Expose Claude Code as an MCP server for other tools:

```bash
claude mcp serve
```

### MCP Resources & Prompts

- **Resources**: Reference with `@server:protocol://path` syntax
- **Prompts**: Invoke as `/mcp__servername__promptname`

### MCP Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `MAX_MCP_OUTPUT_TOKENS` | Max tokens per MCP tool response | — |
| `MCP_TIMEOUT` | Connection timeout for MCP servers | — |

### Our MCP Setup

See `scripts/setup.sh` Phase 4 for our MCP configuration:

```bash
claude mcp add --scope user context7 bunx @upstash/context7-mcp
claude mcp add --scope user steampipe npx @turbot/steampipe-mcp
claude mcp add --scope user playwright bunx @playwright/mcp@latest
claude mcp add --scope user --transport sse deepwiki https://mcp.deepwiki.com/sse
```

**Parity rule**: MCP servers must be configured in both Claude Desktop (`claude_desktop_config.json`) and Claude Code CLI (`setup.sh`). Verify with `claude mcp list`.

---

## Agent Teams

### Enabling Agent Teams

Agent Teams is experimental. Enable via environment variable:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Display Modes

| Mode | Setting | Description |
|------|---------|-------------|
| `in-process` | `--teammate-mode in-process` | All teammates in single terminal |
| `tmux` | `--teammate-mode tmux` | Each teammate in tmux split pane |
| `auto` | Default | Uses tmux if available, else in-process |

Set globally: `"teammateMode": "auto"` in `~/.claude.json`.

### Teammate Interactions

| Action | Method |
|--------|--------|
| Spawn teammate | Ask Claude to create one, or use `Shift+Tab` to delegate |
| Navigate teammates | `Shift+Up/Down` between panes |
| View task list | `Ctrl+T` |
| Kill background agents | `Ctrl+F` (press twice) |

### Plan Approval for Teammates

Teammates can be spawned with `plan_mode_required`, requiring the team lead to approve their implementation plan before they proceed.

### Shared Task List

Teams share a task list with file-locking for coordination. Each teammate can:
- Create tasks (`TaskCreate`)
- Claim tasks (`TaskUpdate` with `owner`)
- Complete tasks (`TaskUpdate` with `status: completed`)
- View all tasks (`TaskList`)

Task list uses `CLAUDE_CODE_TASK_LIST_ID` for named shared lists.

### Hook Events for Teams

| Event | Purpose |
|-------|---------|
| `TeammateIdle` | Enforce quality gates before teammate stops |
| `TaskCompleted` | Validate completion criteria before task closes |

### Best Practices

- **3-5 teammates** per team for optimal coordination
- **5-6 tasks per teammate** to maintain focus
- Assign **different files** per teammate to avoid conflicts
- Provide **specific context** per teammate (no inherited conversation history)
- Use teammates for **same-repo collaborative work**

### Limitations

- No session resumption with in-process teammates
- One team per session
- No nested teams
- Split panes require tmux or iTerm2
- Teammates don't inherit conversation history

### Our Agent Teams Setup

Our dotfiles configure `teammateMode: "auto"` in `~/.claude.json`. For different parallelism patterns:

| Pattern | Tool | Use Case |
|---------|------|----------|
| Personas (single session) | `--persona-*` flags | Domain expertise within one session |
| Agent Teams | `Shift+Tab` delegation | Same-repo parallel work |
| Worktree isolation | `gwt-parallel` | Multi-branch independent work |
| Autonomous execution | `gwt-ticket` + ralph-loop | Single-ticket background agent |

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
| `gwt-ticket` / `gwtt` | `.config/fish/functions/gwt-ticket.fish` | Via ralph-loop, `--max-turns`, `--max-budget-usd` | Autonomous ticket execution |
| `claude-review` | `.config/fish/functions/claude-review.fish` | `-p`, `--max-turns`, `--max-budget-usd`, `--output-format json`, `--json-schema` | Budget-capped PR review |
| `claude-warm` | `.config/fish/functions/claude-warm.fish` | `--name`, context loading | Pre-warm named session for forking |

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

### Model & Thinking Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLAUDE_CODE_EFFORT_LEVEL` | Reasoning effort: `low`, `medium`, `high`, `max`, `auto` (`max` = Opus 4.6 only, session-scoped) | Adaptive |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` | Disable adaptive thinking | `0` |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | Disable 1M context window | `0` |
| `MAX_THINKING_TOKENS` | Max extended thinking budget | — |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Force model for all subagents | — |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Override "opus" alias | — |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Override "sonnet" alias | — |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Override "haiku" alias | — |

### Prompt Caching Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `DISABLE_PROMPT_CACHING` | Disable all prompt caching | Off |
| `DISABLE_PROMPT_CACHING_HAIKU` | Disable caching for Haiku | Off |
| `DISABLE_PROMPT_CACHING_SONNET` | Disable caching for Sonnet | Off |
| `DISABLE_PROMPT_CACHING_OPUS` | Disable caching for Opus | Off |

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
| `ENABLE_TOOL_SEARCH` | MCP tool search behavior | `auto` |

### MCP Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `MAX_MCP_OUTPUT_TOKENS` | Max tokens per MCP response | — |
| `MCP_TIMEOUT` | MCP server connection timeout | — |

### Bash Tool Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `BASH_MAX_TIMEOUT_MS` | Max bash command timeout | 120000 |
| `BASH_MAX_OUTPUT_LENGTH` | Max output length | 50000 |

### Hook Environment Variables

| Variable | Available In | Purpose |
|----------|-------------|---------|
| `CLAUDE_PROJECT_DIR` | All hooks | Project root directory |
| `CLAUDE_PLUGIN_ROOT` | Plugin hooks | Plugin root directory |
| `CLAUDE_ENV_FILE` | SessionStart only | Path to write persistent env vars |
| `CLAUDE_CODE_REMOTE` | All hooks | `"true"` in remote web environments |

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

### Hook-Based Workflows

```bash
# Stop hook to prevent premature completion (ralph-loop pattern)
# Exit 2 to keep Claude working
INPUT=$(cat)
if echo "$INPUT" | jq -r '.last_assistant_message' | grep -q "TICKET_TASK_COMPLETE"; then
  exit 0
fi
echo "Task not complete yet" >&2
exit 2

# Async PostToolUse hook to run tests after file changes
# async: true runs in background without blocking Claude
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/run-tests-async.sh",
        "async": true,
        "timeout": 300
      }]
    }]
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
5. **OAuth MCP servers** — use `--client-id`/`--client-secret` for authenticated MCP integrations
6. **`opusplan` mode** — native alternative to our `claude-pipeline --preset council` for plan/execute switching

### Medium Priority

7. **`--agents` flag** for `gwt-parallel` — define task-specific subagents per worktree
8. **`--strict-mcp-config`** for devcontainers — locked-down MCP in containerized environments
9. **`--no-session-persistence`** for ephemeral CI/CD pipeline runs
10. **Subagent `memory: user`** — persistent cross-session learning for our plugin agents
11. **Subagent `isolation: worktree`** — native worktree isolation without our `gwt-*` wrapper
12. **Managed MCP** (`managed-mcp.json`) — enterprise deployment of standardized MCP servers
13. **MCP allowlists/denylists** — restrict which MCP servers are permitted per project
14. **`ConfigChange` hooks** — audit configuration changes for security compliance
15. **Agent hooks** (`type: "agent"`) — multi-turn verification with tool access for quality gates

### Lower Priority

16. **`--setting-sources`** — selective settings loading for testing
17. **`--mcp-config`** — per-session MCP overrides for specialized tasks
18. **`--from-pr`** — resume sessions linked to PRs for review workflows
19. **Sandbox `network.allowedDomains`** — domain-level network restrictions for security
20. **`CLAUDE_ENV_FILE`** in SessionStart — persist env vars without Fish config
21. **`claude mcp serve`** — expose Claude Code as MCP server for other tools

---

## See Also

- [Claude Code Hooks Reference](claude-code-hooks.md) — hook events, types, our setup
- [Skills Reference](skills-reference.md) — skill sources, format, migration guide
- [Claude Code LSP Integration](claude-code-lsp.md) — LSP servers for Claude Code
- [Claude Pipeline](claude-pipeline.md) — multi-model reasoning chains
- [Neovim-Claude Bridge](nvim-claude-bridge.md) — editor state awareness
- [Official CLI Reference](https://code.claude.com/docs/en/cli-reference) — upstream source
- [Official Hooks](https://code.claude.com/docs/en/hooks) — hook events and configuration
- [Official Model Config](https://code.claude.com/docs/en/model-config) — model aliases and effort levels
- [Official Common Workflows](https://code.claude.com/docs/en/common-workflows) — piping, sessions, images
- [Official Agent Teams](https://code.claude.com/docs/en/agent-teams) — teammate coordination
- [Official MCP](https://code.claude.com/docs/en/mcp) — MCP server configuration
- [Official Settings](https://code.claude.com/docs/en/settings) — configuration reference
- [Official Permissions](https://code.claude.com/docs/en/permissions) — permission system
- [Official Subagents](https://code.claude.com/docs/en/sub-agents) — subagent documentation
- [Official Skills](https://code.claude.com/docs/en/skills) — skills documentation
