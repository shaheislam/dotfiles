# Claude Code Hooks Analysis — Complete Audit & Novel Use Cases

> Generated 2026-02-13 from analysis of our dotfiles repo, external references
> ([disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery),
> [letanure.dev hooks guide](https://www.letanure.dev/blog/2025-08-06--claude-code-part-8-hooks-automated-quality-checks)),
> and our Neovim/dotfiles ecosystem.

---

## Table of Contents

- [Part 1: How We Currently Use Hooks](#part-1-how-we-currently-use-hooks)
- [Part 2: Unwired Hooks Ready to Activate](#part-2-unwired-hooks-ready-to-activate)
- [Part 3: External Patterns We Don't Have](#part-3-external-patterns-we-dont-have)
- [Part 4: Novel Use Cases for Our AI Workflow](#part-4-novel-use-cases-for-our-ai-workflow)
- [Part 5: Recommended Implementation Priority](#part-5-recommended-implementation-priority)

---

## Part 1: How We Currently Use Hooks

### Active Hooks (7 events, 11 hook instances)

| # | Event | Script | What It Does | Why It Matters |
|---|-------|--------|-------------|----------------|
| 1 | **SessionStart** | `fix-hookify-imports.sh` | Patches hookify plugin imports on every session start | Prevents plugin load failures from import mismatches |
| 2 | **SessionStart** | `bd prime` | Primes Beads agent memory from `.beads/` | Gives Claude project context from previous sessions |
| 3 | **PreToolUse** (Bash) | `use_bun.py` | Blocks npm/npx/yarn/pnpm, suggests bun/bunx | Enforces package manager consistency. Logs violations to `bun_enforcement.json` |
| 4 | **PreToolUse** (Bash) | `validate-bash.py` | Blocks `rm -rf /`, `sudo rm`, `dd of=/dev/`, direct disk writes | Safety net against destructive commands. Fail-closed (bad JSON → block). Has allowlist for devcontainer/worktree/docker |
| 5 | **PostToolUse** (Read) | `deepwiki-context.py` | Detects file language by extension, injects DeepWiki repo suggestions | Passive context — when Claude reads a `.py` file, it gets reminded about `python/cpython`, `fastapi/fastapi`, etc. |
| 6 | **PreCompact** | `bd prime` | Re-injects Beads workflow context before compaction | Prevents memory loss during auto-compact |
| 7 | **Notification** | `macos_notification.py` | macOS desktop notification (osascript) with type-specific sounds | Basso for errors, Sosumi for warnings, Glass for success, Blow for info |
| 8 | **Notification** | `log-notification.sh` | Logs notifications to `~/.claude/hooks/logs/notifications-YYYY-MM-DD.log` | Audit trail of all Claude notifications |
| 9 | **UserPromptSubmit** | `checkpoint-pre-prompt.sh` | Captures transcript offset, untracked files, timestamp before each prompt | Pre-state for checkpoint diff extraction |
| 10 | **Stop** | `checkpoint-capture.sh` (10s timeout) | Extracts transcript slice, files modified, summary after Claude responds | Creates checkpoint metadata tied to commits |
| 11 | **Stop** | `cross-provider-bridge.sh` (180s timeout) | Sends last Claude response to Codex/Gemini/Ollama/DeepSeek/OpenCode for independent review. Iterative consensus loop. | Correlation-bias mitigation — an independent AI reviews Claude's work. Blocks stop if concerns remain. |

### Architecture Patterns We Use

1. **Exit code 2 for blocking**: `use_bun.py` and `validate-bash.py` use exit 2 to force Claude to correct its command
2. **Silent failure for non-critical hooks**: `deepwiki-context.py`, `bd prime/sync` use `2>/dev/null || true` to never block sessions
3. **Iterative consensus via Stop hook**: `cross-provider-bridge.sh` creates a multi-turn review loop by blocking the Stop event until a reviewer agrees or max iterations are reached — unique pattern not seen elsewhere
4. **Layered checkpointing**: UserPromptSubmit captures pre-state, Stop captures post-state, git hooks tie it to commits
5. **Provider chain with graceful fallback**: cross-provider-bridge tries providers in order, silently continues if all fail

### Coverage Gaps (Events We Don't Use)

| Event | Status | Why Not |
|-------|--------|---------|
| `SessionEnd` | Not wired | JFDI `session-end-extract.py` exists but depends on `lib/` module not present |
| `PostToolUseFailure` | Not wired | No error tracking for failed tool calls |
| `PermissionRequest` | Not wired | No auto-allow for read-only operations |
| `SubagentStart` | Not wired | No subagent spawn tracking |
| `SubagentStop` | Not wired | No subagent completion notification |
| `TeammateIdle` | Not wired | Agent Teams quality gates not implemented |
| `TaskCompleted` | Not wired | No task completion enforcement |
| `Setup` | Not wired | No repo initialization hook |

---

## Part 2: Unwired Hooks Ready to Activate

### Scripts in `.claude/hooks/` Not Wired to settings.json

| Script | Target Event | What It Does | Effort to Wire |
|--------|-------------|-------------|----------------|
| `add-context.py` | UserPromptSubmit | Injects timestamp, git branch, modified file count, Python version, and secret detection warnings | Low — just add to settings.json. Useful for audit trails. |
| `file-modified.sh` | PostToolUse (Edit\|Write) | Logs file modifications, runs Python syntax check on `.py` files, JSON validation on `.json` files | Low — simple PostToolUse matcher |
| `log_pre_tool_use.py` | PreToolUse | Logs all tool invocations with timestamp, session ID, tool name, command to `bash_commands.json` | Low — adds full audit trail |
| `ts_lint.py` | PostToolUse (Edit\|Write) | Runs ESLint on `.ts/.tsx/.js/.jsx` files after edit | Medium — requires ESLint installed. Uses npx (should be converted to bunx) |
| `play_audio.py` | Notification | Plays macOS system sounds (Glass.aiff) via afplay | Low — alternative/complement to `macos_notification.py` |

### JFDI Hooks (Require `lib/` Module)

| Script | Target Event | What It Does | Effort to Wire |
|--------|-------------|-------------|----------------|
| `jfdi/audit-log.py` | PostToolUse | Logs Edit/Write/Bash/Task/WebFetch/WebSearch actions with context to markdown files organized by date | High — needs `lib/config.py`, `lib/markdown_writer.py` |
| `jfdi/prompt-inject-context.py` | UserPromptSubmit | Searches memory vault (Obsidian) for relevant corrections, entities, keywords; injects `<memory_context>` into prompts | High — needs `lib/ripgrep_search.py`, `lib/config.py`, Obsidian vault |
| `jfdi/session-end-extract.py` | SessionEnd | Parses transcript, detects memory triggers (corrections, recovery patterns), calls Claude CLI to extract memories, writes to Obsidian vault | High — needs full `lib/` suite and Claude CLI access from hook |

---

## Part 3: External Patterns We Don't Have

### From disler/claude-code-hooks-mastery

| Pattern | Event | What It Does | Our Equivalent |
|---------|-------|-------------|----------------|
| **All 13 events wired** | All | Every hook event has a handler, even if just logging | We cover 7/13 events |
| **Status line via hook** | StatusLine | Custom colored terminal status showing model, context usage %, remaining tokens, session ID | We don't use statusLine config |
| **TTS completion announcement** | Stop + SubagentStop | Text-to-speech via ElevenLabs/OpenAI/pyttsx3 priority chain with queue-based lock to prevent overlapping audio | We have macOS notification but no TTS |
| **Subagent task summarization** | SubagentStop | Uses Anthropic API to summarize what the subagent accomplished, then announces via TTS | Not implemented |
| **PreCompact transcript backup** | PreCompact | Backs up full transcript before compaction | We sync Beads but don't back up transcript |
| **PermissionRequest auto-allow** | PermissionRequest | Auto-approves Read, Glob, Grep, safe Bash commands | Not implemented — we approve manually |
| **PostToolUseFailure logging** | PostToolUseFailure | Captures error details with full context for analysis | Not implemented |
| **Setup hook for repo init** | Setup | Fires during repo initialization, sets up dependencies | Not implemented |
| **Builder/Validator agent pattern** | SubagentStart/Stop | Builder agent with full tools, Validator agent restricted to read-only | Not in hooks — done via pr-review-toolkit plugin |
| **UV single-file scripts** | All | Each hook is a self-contained UV script with inline dependency declarations | We use shebang python3, no dependency management |
| **Output style configurations** | Commands | 8 markdown files defining output formatting: GenUI, table-based, YAML, bullets, ultra-concise, etc. | We use plugin-based output styles |

### From letanure.dev Blog

| Pattern | Event | What It Does | Our Equivalent |
|---------|-------|-------------|----------------|
| **Auto-format after edit** | PostToolUse (Edit\|Write) | Runs `prettier --write` on modified files automatically | Not implemented |
| **Type checking after edit** | PostToolUse (Edit\|Write) | Runs `pnpm type:check --noEmit` after TypeScript edits | `ts_lint.py` exists but unwired |
| **Security path matcher** | PreToolUse (Read\|Edit) | Matches `src/auth/*` paths for security-specific validation | `validate-bash.py` blocks dangerous commands but doesn't do path-based security |
| **Test-related file triggers** | PostToolUse (Edit) | Matcher `Edit:*.test.*` runs related tests | Not implemented |
| **Communication optimization** | UserPromptSubmit | Injects "Skip acknowledgments - focus on the solution" to every prompt | We use plugin output styles instead |
| **Commit quality gates** | PreToolUse (Bash) | Blocks git commit if tests fail or linting errors exist | Not implemented via hooks |

---

## Part 4: Novel Use Cases for Our AI Workflow

### Tier 1: High-Impact, Low-Effort (Wire Existing Scripts)

#### 1. PostToolUseFailure — Error Pattern Tracking
**Why**: When Claude's tool calls fail (e.g., file not found, syntax errors in Bash), we currently lose that information. Tracking failures reveals recurring problems.

```json
{
  "PostToolUseFailure": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "python3 ~/.claude/hooks/log-tool-failure.py 2>/dev/null || true"
        }
      ]
    }
  ]
}
```

#### 2. Auto-Format Shell Scripts After Edit
**Why**: We write lots of Fish/Bash scripts. Auto-running `shfmt` after edits catches formatting issues immediately.

```json
{
  "PostToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "command",
          "command": "python3 ~/.claude/hooks/auto-format.py 2>/dev/null || true"
        }
      ]
    }
  ]
}
```

The hook would detect `.sh`/`.bash` → `shfmt -w`, `.fish` → `fish_indent`, `.py` → `ruff format`, `.json` → `jq .`.

#### 3. Protected Files Guard
**Why**: Prevent accidental edits to critical files like `.claude/settings.json`, `scripts/setup.sh` (without intent), `Brewfile`, `.tmux.conf`.

```json
{
  "PreToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "command",
          "command": "python3 ~/.claude/hooks/protect-files.py",
          "statusMessage": "Checking file protection..."
        }
      ]
    }
  ]
}
```

#### 4. PermissionRequest Auto-Allow for Read-Only Operations
**Why**: Eliminates repetitive permission prompts for safe operations, dramatically speeding up research/exploration phases.

```json
{
  "PermissionRequest": [
    {
      "matcher": "Read|Glob|Grep",
      "hooks": [
        {
          "type": "command",
          "command": "python3 ~/.claude/hooks/auto-allow-readonly.py"
        }
      ]
    }
  ]
}
```

### Tier 2: Medium-Impact, Medium-Effort (New Scripts)

#### 5. Worktree-Aware Context Injection (SessionStart)
**Why**: When `gwt-ticket` launches Claude in a worktree, auto-inject the ticket context, branch name, and worktree state.

```json
{
  "SessionStart": [
    {
      "matcher": "startup",
      "hooks": [
        {
          "type": "command",
          "command": "bash ~/.claude/hooks/worktree-context.sh"
        }
      ]
    }
  ]
}
```

The hook would detect if CWD is a git worktree, read the branch name (often ticket IDs), check for `.ralph-loop.local.md`, and inject context about which ticket is being worked on.

#### 6. Post-Compact Memory Re-injection
**Why**: After auto-compact, Claude loses context. A `SessionStart` hook matching `compact` can re-inject critical rules and project context that would otherwise be lost.

```json
{
  "SessionStart": [
    {
      "matcher": "compact",
      "hooks": [
        {
          "type": "command",
          "command": "bash ~/.claude/hooks/post-compact-reinject.sh"
        }
      ]
    }
  ]
}
```

Would output: project rules reminders (Bun not npm, Tokyo Night theme), current git state, active todo items, and any `.beads` context.

#### 7. SubagentStop — Agent Completion Notification + Summary
**Why**: When spawning agents via Task tool (especially in Agent Teams), get a desktop notification + brief summary of what the agent accomplished.

```json
{
  "SubagentStop": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "python3 ~/.claude/hooks/subagent-notify.py 2>/dev/null || true"
        }
      ]
    }
  ]
}
```

Reads `agent_transcript_path`, extracts first user message + last assistant message, sends macOS notification. Integrates with `openclaw-notify` for mobile alerts.

#### 8. Git Commit Quality Gate
**Why**: Block `git commit` via PreToolUse if there are shellcheck warnings in modified `.sh` files, or if Fish syntax is invalid in modified `.fish` files.

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "python3 ~/.claude/hooks/pre-commit-quality.py",
          "statusMessage": "Checking commit quality..."
        }
      ]
    }
  ]
}
```

Detects `git commit` commands, runs `shellcheck` on staged `.sh` files, `fish --no-execute` on staged `.fish` files.

### Tier 3: High-Impact, High-Effort (Architectural)

#### 9. Session Cost Tracker (StatusLine + Stop)
**Why**: Track cumulative token usage and estimated cost per session. Display in status line. Log to file on SessionEnd.

This requires:
- A `StatusLine` command that reads context window usage from stdin
- A `Stop` hook that logs cumulative usage
- A `SessionEnd` hook that writes the session cost summary

#### 10. Intelligent Test Runner (PostToolUse + async)
**Why**: After editing source files, automatically run related tests in the background. Don't block Claude — use `async: true`. Feed results back on next turn.

```json
{
  "PostToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "command",
          "command": "bash ~/.claude/hooks/async-test-runner.sh",
          "async": true,
          "timeout": 300
        }
      ]
    }
  ]
}
```

Maps source files to test files using naming conventions, runs only affected tests.

#### 11. Neovim LSP Integration (PostToolUse)
**Why**: When Claude edits files in our Nix-managed LSP environment, automatically trigger LSP diagnostics check. Since we use the 3-tier LSP system (Global → Project → Neovim), validate that the edited file's language server is available and report any diagnostics.

This would hook into `nix develop` or check `nix/global/flake.nix` for available LSPs matching the edited file's language.

#### 12. Agent Teams Quality Gate (TeammateIdle + TaskCompleted)
**Why**: When using Agent Teams, enforce that teammates can't go idle without completing their assigned task, and tasks can't be marked complete without tests passing.

```json
{
  "TaskCompleted": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash ~/.claude/hooks/task-quality-gate.sh"
        }
      ]
    }
  ]
}
```

---

## Part 5: Recommended Implementation Priority

### Phase 1: Quick Wins (1-2 hours)

1. **Wire `file-modified.sh`** to PostToolUse (Edit|Write) — already exists, just needs settings.json entry
2. **Wire `add-context.py`** to UserPromptSubmit — already exists, adds git/timestamp context
3. **Create `log-tool-failure.py`** for PostToolUseFailure — simple logging script
4. **Add post-compact reinject** to SessionStart (compact matcher) — echoes critical rules

### Phase 2: Safety & Speed (2-4 hours)

5. **Create `protect-files.py`** for PreToolUse (Edit|Write) — blocks edits to critical paths
6. **Create `auto-allow-readonly.py`** for PermissionRequest — auto-approves Read/Glob/Grep
7. **Create `pre-commit-quality.py`** for PreToolUse (Bash) — blocks bad commits
8. **Create `auto-format.py`** for PostToolUse (Edit|Write) — language-aware formatting

### Phase 3: Agent Workflow Integration (4-8 hours)

9. **Create `worktree-context.sh`** for SessionStart (startup) — ticket/branch context injection
10. **Create `subagent-notify.py`** for SubagentStop — completion notifications with summary
11. **Create `async-test-runner.sh`** for PostToolUse (async) — background test execution
12. **Create `task-quality-gate.sh`** for TaskCompleted — enforce test passage

### Phase 4: Advanced (8+ hours)

13. **Implement StatusLine** — context window usage display
14. **Port JFDI hooks** — memory injection, audit logging, session-end extraction (needs `lib/` module)
15. **Neovim LSP integration** — PostToolUse diagnostic checking

---

## Appendix: Hook Event Coverage Comparison

| Event | Our Dotfiles | disler/hooks-mastery | letanure.dev |
|-------|:---:|:---:|:---:|
| SessionStart | 2 hooks | 1 hook | - |
| SessionEnd | unwired | 1 hook | - |
| Setup | - | 1 hook | - |
| UserPromptSubmit | 1 hook | 1 hook | 1 hook |
| PreToolUse | 2 hooks (Bash) | 1 hook | 2 hooks |
| PostToolUse | 1 hook (Read) | 1 hook | 3 hooks |
| PostToolUseFailure | - | 1 hook | - |
| PermissionRequest | - | 1 hook | - |
| Notification | 2 hooks | 1 hook (TTS) | - |
| Stop | 2 hooks | 1 hook (TTS) | - |
| SubagentStart | - | 1 hook | - |
| SubagentStop | - | 1 hook (TTS) | - |
| PreCompact | 1 hook | 1 hook | - |
| TeammateIdle | - | - | - |
| TaskCompleted | - | - | - |
| **Total hooks** | **11** | **13** | **6** |
| **Events covered** | **7/15** | **13/15** | **3/15** |

---

## Appendix: Novel Ideas Specific to Our Ecosystem

### Ideas That Leverage Our Unique Stack

1. **Ralph-Loop Iteration Counter** (Stop hook): When `stop_hook_active` is true during a ralph-loop, increment an iteration counter and inject it as context. Helps ralph-loop sessions track where they are without reading the state file.

2. **Cross-Provider Bridge + OpenClaw** (Stop hook enhancement): Route cross-provider review notifications through OpenClaw's multi-channel inbox, so you get the review on Telegram/Slack/Discord in real-time.

3. **Checkpoint-Aware Compaction** (PreCompact): Before auto-compact, create a checkpoint of the current session state (not just Beads sync). This preserves the "why" context that would otherwise be lost.

4. **gwt-queue Dispatch Notification** (Notification): When the ticket queue daemon dispatches a new ticket, fire an OpenClaw notification with ticket details and worktree info.

5. **Stow Conflict Detection** (PostToolUse Edit|Write): After editing dotfiles, check if the edit would create a stow conflict (file exists in home dir but isn't a symlink). Warn before the conflict manifests during `stow`.

6. **tmux Watcher Integration** (SubagentStop): When a subagent completes in a tmux-based Agent Teams session, update the tmux-claude-watcher status to show completion. Currently watcher only tracks idle/stuck.

7. **Fish Function Syntax Validation** (PostToolUse Edit|Write): When editing `.config/fish/functions/*.fish`, run `fish --no-execute` to validate syntax before the function gets loaded. Our dotfiles are primarily Fish — this catches errors early.

8. **Prompt-Based CLAUDE.md Compliance** (UserPromptSubmit): Use a `type: "prompt"` hook to check if the user's request would violate CLAUDE.md rules (e.g., "create a tmux config in .config/tmux/" should be blocked per our rules). Lightweight LLM check.

9. **Session Handoff Context** (SessionEnd): On session end, write a brief context summary to a well-known file that the next session's SessionStart hook reads. Enables cross-session continuity without Beads.

10. **MCP Server Health Check** (SessionStart): On startup, verify that critical MCP servers (Context7, DeepWiki, Steampipe) are responding. Log warnings for unavailable servers so Claude can adapt its tool selection.
