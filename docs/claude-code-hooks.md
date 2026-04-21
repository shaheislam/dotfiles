# Claude Code Hooks - Complete Integration Guide

> Reference for the hooks system in our dotfiles setup based on official documentation at
> [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) and
> [code.claude.com/docs/en/hooks-guide](https://code.claude.com/docs/en/hooks-guide).
> Covers all hook events, the 3 hook types, our existing hooks, activation patterns, and recipes.

## Table of Contents

- [What Are Hooks?](#what-are-hooks)
- [Hook Events Reference](#hook-events-reference)
- [Hook Types](#hook-types)
- [Configuration](#configuration)
- [Our Current Hooks Setup](#our-current-hooks-setup)
- [Available But Unconfigured Hooks](#available-but-unconfigured-hooks)
- [Recipes & Patterns](#recipes--patterns)
- [Codex Comparison](#codex-comparison)
- [Debugging & Troubleshooting](#debugging--troubleshooting)

---

## What Are Hooks?

Hooks are user-defined shell commands or LLM prompts that execute automatically at specific points in Claude Code's lifecycle. They provide **deterministic control** — ensuring certain actions always happen rather than relying on the LLM to choose to run them.

**Key properties:**
- Run with your system user's full permissions
- Communicate via stdin (JSON), stdout (JSON/text), stderr (error messages), and exit codes
- Can block, allow, modify, or inject context into Claude's workflow
- Are snapshot'd at session startup (mid-session file edits require `/hooks` review)

**Three hook types:**
1. **Command** (`type: "command"`): Run a shell script. Most common.
2. **Prompt** (`type: "prompt"`): Send to a Claude model for single-turn yes/no evaluation.
3. **Agent** (`type: "agent"`): Spawn a subagent with tool access (Read, Grep, Glob) for multi-turn verification.

---

## Hook Events Reference

### Lifecycle Overview

```
SessionStart → [UserPromptSubmit → PreToolUse → PermissionRequest → PostToolUse/PostToolUseFailure → ... → Stop] → SessionEnd
                                                                                                    ↑
                                                                          SubagentStart → SubagentStop
                                                                          Notification (anytime)
                                                                          PreCompact (before compaction)
                                                                          TeammateIdle (agent teams)
                                                                          TaskCompleted (task lists)
```

### Event Quick Reference

| Event | Fires When | Can Block? | Matcher Field | Key Input Fields |
|-------|-----------|-----------|---------------|------------------|
| `SessionStart` | Session begins/resumes | No | `startup\|resume\|clear\|compact` | `source`, `model` |
| `UserPromptSubmit` | User submits prompt | Yes | None (always fires) | `prompt` |
| `PreToolUse` | Before tool executes | Yes | Tool name (`Bash`, `Edit`, etc.) | `tool_name`, `tool_input` |
| `PermissionRequest` | Permission dialog shown | Yes | Tool name | `tool_name`, `tool_input`, `permission_suggestions` |
| `PostToolUse` | After tool succeeds | No (feedback only) | Tool name | `tool_name`, `tool_input`, `tool_response` |
| `PostToolUseFailure` | After tool fails | No (feedback only) | Tool name | `tool_name`, `tool_input`, `error` |
| `Notification` | Claude sends notification | No | `permission_prompt\|idle_prompt\|auth_success\|elicitation_dialog` | `message`, `notification_type` |
| `SubagentStart` | Subagent spawned | No (context only) | Agent type | `agent_id`, `agent_type` |
| `SubagentStop` | Subagent finishes | Yes | Agent type | `agent_id`, `agent_type`, `agent_transcript_path` |
| `Stop` | Claude finishes responding | Yes | None (always fires) | `stop_hook_active` |
| `TeammateIdle` | Teammate about to idle | Yes (exit 2 only) | None | `teammate_name`, `team_name` |
| `TaskCompleted` | Task marked complete | Yes (exit 2 only) | None | `task_id`, `task_subject` |
| `PreCompact` | Before compaction | No | `manual\|auto` | `trigger`, `custom_instructions` |
| `SessionEnd` | Session terminates | No | `clear\|logout\|prompt_input_exit\|other` | `reason` |

### Exit Code Semantics

| Exit Code | Meaning | Behavior |
|-----------|---------|----------|
| `0` | Success | Action proceeds. stdout parsed for JSON. For `UserPromptSubmit`/`SessionStart`, stdout is added as context. |
| `2` | Blocking error | Action blocked. stderr fed back to Claude. JSON on stdout is ignored. |
| Other | Non-blocking error | Action proceeds. stderr shown in verbose mode only. |

### Decision Control Patterns

Different events use different JSON output patterns:

**Top-level `decision` (UserPromptSubmit, PostToolUse, Stop, SubagentStop):**
```json
{ "decision": "block", "reason": "Tests must pass first" }
```

**`hookSpecificOutput` (PreToolUse):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Use bun instead of npm"
  }
}
```

**`hookSpecificOutput` (PermissionRequest):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": { "behavior": "allow", "updatedInput": { "command": "bun test" } }
  }
}
```

**Exit code 2 only (TeammateIdle, TaskCompleted):**
```bash
echo "Tests not passing" >&2
exit 2
```

---

## Hook Types

### Command Hooks (`type: "command"`)

Most common. Runs a shell command that receives JSON on stdin.

```json
{
  "type": "command",
  "command": "python3 ~/.claude/hooks/my-hook.py",
  "timeout": 30,
  "statusMessage": "Running validation...",
  "async": false
}
```

**Async mode**: Set `async: true` to run in background. Claude continues working. Result delivered on next turn. Cannot block actions.

### Prompt Hooks (`type: "prompt"`)

Single-turn LLM evaluation. Returns `{"ok": true/false, "reason": "..."}`.

```json
{
  "type": "prompt",
  "prompt": "Check if all tasks are complete: $ARGUMENTS",
  "model": "haiku",
  "timeout": 30
}
```

Supported events: PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, UserPromptSubmit, Stop, SubagentStop, TaskCompleted.

### Agent Hooks (`type: "agent"`)

Multi-turn subagent with tool access (Read, Grep, Glob). Up to 50 turns.

```json
{
  "type": "agent",
  "prompt": "Verify all unit tests pass. Run test suite and check results. $ARGUMENTS",
  "timeout": 120
}
```

Same supported events as prompt hooks. Use when verification requires inspecting actual files.

---

## Configuration

### Settings File Locations

Hooks are configured directly in `settings.json` files per the
[official documentation](https://code.claude.com/docs/en/hooks). There is no
CLI command for hook registration — `claude plugin` manages plugins, not hooks.

| Location | Scope | Shareable |
|----------|-------|-----------|
| `~/.claude/settings.json` | All projects | No (local machine) |
| `.claude/settings.json` | Single project | Yes (committed) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy | Organization-wide | Yes (admin) |
| Plugin `hooks/hooks.json` | When plugin enabled | Yes (bundled) |
| Skill/agent frontmatter | While active | Yes (component file) |

### Configuration Structure

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "regex_pattern",
        "hooks": [
          {
            "type": "command",
            "command": "path/to/script.sh",
            "timeout": 30,
            "statusMessage": "Custom spinner text..."
          }
        ]
      }
    ]
  }
}
```

### Environment Variables Available to Hooks

| Variable | Description |
|----------|-------------|
| `$CLAUDE_PROJECT_DIR` | Project root directory |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin root (for plugin hooks) |
| `$CLAUDE_ENV_FILE` | File path for persisting env vars (SessionStart only) |
| `$CLAUDE_CODE_REMOTE` | `"true"` in remote web environments |

### Common Input Fields (All Events)

| Field | Description |
|-------|-------------|
| `session_id` | Current session identifier |
| `transcript_path` | Path to conversation JSONL |
| `cwd` | Current working directory |
| `permission_mode` | `default\|plan\|acceptEdits\|dontAsk\|bypassPermissions` |
| `hook_event_name` | Name of the event that fired |

### MCP Tool Matching

MCP tools follow pattern `mcp__<server>__<tool>`:
- `mcp__memory__create_entities` - Memory server
- `mcp__github__search_repositories` - GitHub server
- Use `mcp__memory__.*` to match all tools from a server

---

## Our Current Hooks Setup

### Active Hooks (in `.claude/settings.json`)

| Event | Matcher | Hook Chain | Purpose |
|-------|---------|------------|---------|
| **SessionStart** | `""` | `fix-hookify-imports.sh`, `entire ... session-start`, tmux start hook, `plugin-chmod-fix.sh`, `bd prime`, `work-detect.sh`, `lsp-status.sh`, `plan-resume.sh`, `changelog-resume.sh`, `dream/count-session.sh` | Startup repair, session recovery, memory/context injection |
| **SessionStart** | `compact` | `post-compact-reinject.sh` | Re-inject high-signal reminders after compaction |
| **PreToolUse** | `Task` | `entire ... pre-task` | Task/checkpoint lifecycle integration |
| **PreToolUse** | `Bash` | `use_bun.py`, `validate-bash.py`, `ci-precommit.sh` | Bun enforcement, dangerous-command blocking, lightweight checks |
| **PreToolUse** | `Edit\|Write` | `settings-edit-redirect.py` | Force settings edits through Bash + `jq` |
| **PostToolUse** | `Read` | `deepwiki-context.py` | Language-aware docs suggestions |
| **PostToolUse** | `Task`, `TodoWrite` | `entire ... post-task`, `entire ... post-todo` | Persist task transitions |
| **PostToolUse** | `Edit\|Write` | `auto-format.py`, `file-modified.sh`, `ci-lint-on-save.sh` | Format, log edits, and lint changed files |
| **PostToolUse** | `""` | `plan-watch.sh` | Keep `.plan.md` current after tool activity |
| **PreCompact** | `""` | `bd prime`, `plan-persist.sh`, `changelog-persist.sh` | Preserve beads, plan, and recent changelog before compaction |
| **Notification** | `""` | `macos_notification.py`, `log-notification.sh`, tmux notify hook | Local alerts and audit logging |
| **UserPromptSubmit** | `""` | `nvim-bridge.sh`, `entire ... user-prompt-submit`, tmux prompt hook, `jfdi/prompt-inject-context.py` | Editor bridge, checkpointing, and prompt context enrichment |
| **SubagentStart / SubagentStop** | `""` | `log-notification.sh` | Log subagent lifecycle events |
| **Stop** | `""` | `cross-provider-bridge.sh`, `entire ... stop`, tmux stop hook, Obsidian synthesis, `jfdi/session-end-extract.py`, `dream-hook.sh` | End-of-response review and memory extraction |
| **SessionEnd** | `""` | `entire ... session-end`, tmux end hook, `session-report.sh`, Obsidian synthesis | Final session reporting |
| **WorktreeCreate / WorktreeRemove** | `""` | `worktree-init.sh`, `worktree-cleanup.sh` | Worktree lifecycle automation |

> **Note**: `entire` now owns the checkpoint lifecycle hooks; the repo adds plan/changelog and repo-specific integration hooks around it.

### Hook Scripts Inventory (`.claude/hooks/`)

| Script | Type | Wiring |
|--------|------|--------|
| `use_bun.py` | Python | Active in `PreToolUse (Bash)` |
| `validate-bash.py` | Python | Active in `PreToolUse (Bash)` |
| `deepwiki-context.py` | Python | Active in `PostToolUse (Read)` |
| `auto-format.py` | Python | Active in `PostToolUse (Edit\|Write)` |
| `file-modified.sh` | Bash | Active in `PostToolUse (Edit\|Write)` |
| `macos_notification.py` | Python | Active in `Notification` |
| `log-notification.sh` | Bash | Active in `Notification`, `SubagentStart`, `SubagentStop` |
| `plan-resume.sh` / `plan-persist.sh` | Bash | Active in `SessionStart`, `PreCompact` |
| `changelog-resume.sh` / `changelog-persist.sh` / `changelog-append.sh` | Bash | Active in `SessionStart`, `PreCompact`, manual append helper |
| `nvim-bridge.sh` | Bash | Active in `UserPromptSubmit` |
| `work-detect.sh` | Bash | Active in `SessionStart` |
| `post-compact-reinject.sh` | Bash | Active in `SessionStart (compact)` |
| `jfdi/prompt-inject-context.py` | Python | Active in `UserPromptSubmit` |
| `jfdi/session-end-extract.py` | Python | Active in `Stop` |

### Available But Currently Unwired

These hooks still exist as optional building blocks, but they are not currently wired in project settings: `add-context.py`, `log_pre_tool_use.py`, `ts_lint.py`, `play_audio.py`, and `subagent-lifecycle.sh`.

### Validation

Run `scripts/test-filter.sh hooks` after editing hook scripts or `.claude/settings.json`. The filtered suite checks executability, syntax, key wiring, ordering, and changelog/plan persistence smoke behavior.

---

## Recipes & Patterns

### Pattern 1: Protected Files (PreToolUse)

Block edits to sensitive files:

```bash
#!/bin/bash
# .claude/hooks/protect-files.sh
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROTECTED=(".env" ".git/" "package-lock.json" "node_modules/" "*.key" "*.pem")

for pattern in "${PROTECTED[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
        echo "Blocked: $FILE_PATH matches protected pattern '$pattern'" >&2
        exit 2
    fi
done
exit 0
```

Config:
```json
{ "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-files.sh" }] }
```

### Pattern 2: Auto-Format After Edits (PostToolUse)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs bunx prettier --write 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

### Pattern 3: Block PR if Tests Fail (PreToolUse + MCP)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__github__create_pull_request",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-pr-require-tests.sh"
          }
        ]
      }
    ]
  }
}
```

### Pattern 4: Context Re-injection After Compaction (SessionStart)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Reminder: use Bun not npm. Run tests before committing. Theme: Tokyo Night.'"
          }
        ]
      }
    ]
  }
}
```

### Pattern 5: Prompt-Based Stop Gate

Use LLM to verify completion:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Evaluate if Claude should stop: $ARGUMENTS. Check if: 1) All tasks complete 2) No errors need addressing 3) No follow-up needed. Respond with {\"ok\": true} or {\"ok\": false, \"reason\": \"what remains\"}.",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Pattern 6: Agent-Based Test Verification

Use agent with tool access to verify tests:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Verify all tests pass. Check test output and coverage. $ARGUMENTS",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

### Pattern 7: Async Background Tests (PostToolUse)

Run tests without blocking:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/run-tests-async.sh",
            "async": true,
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

### Pattern 8: Environment Variable Persistence (SessionStart)

```bash
#!/bin/bash
# Persist env vars for the session
if [ -n "$CLAUDE_ENV_FILE" ]; then
    echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"
    echo 'export PATH="$PATH:./node_modules/.bin"' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

### Pattern 9: Teammate Quality Gate (TeammateIdle)

```bash
#!/bin/bash
# Require build artifact before teammate can idle
if [ ! -f "./dist/output.js" ]; then
    echo "Build artifact missing. Run build first." >&2
    exit 2
fi
exit 0
```

### Pattern 10: Task Completion Enforcement (TaskCompleted)

```bash
#!/bin/bash
INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject')

if ! npm test 2>&1; then
    echo "Tests failing. Fix before completing: $TASK_SUBJECT" >&2
    exit 2
fi
exit 0
```

### Pattern 11: Audit Trail (PreToolUse + Bash logging)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.command' >> ~/.claude/command-log.txt"
          }
        ]
      }
    ]
  }
}
```

### Pattern 12: Input Modification (PreToolUse updatedInput)

Rewrite tool input before execution:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "command": "bun test"
    }
  }
}
```

---

## Codex Comparison

Based on [Codex CLI reference](https://developers.openai.com/codex/cli/reference/) (Feb 2026), Codex has a notification hook that fires when the agent finishes a turn, but no broader lifecycle hook system. See [GitHub Discussion #2150](https://github.com/openai/codex/discussions/2150) for community requests.

| Feature | Claude Code ([docs](https://code.claude.com/docs/en/hooks)) | Codex CLI ([docs](https://developers.openai.com/codex/cli/reference/)) |
|---------|------------|-----------|
| Hook events | SessionStart, PreToolUse, PostToolUse, Stop, etc. | Notification only |
| Hook types | Command, Prompt, Agent | Command only |
| Blocking capability | PreToolUse, Stop, UserPromptSubmit, etc. | No |
| Input modification | `updatedInput` on PreToolUse | No |
| Context injection | SessionStart, UserPromptSubmit | No |
| Async hooks | Yes (background execution) | No |
| Matcher patterns | Regex on tool names/events | No |

For our cross-provider bridge, we use Codex as a *consumer* (via `codex exec`) rather than a hook provider. If Codex adds hooks in the future, we could consider lightweight pre-shell intercepts as the reviewer suggested.

---

## Validation Checklist

Run these after any hooks change:

```bash
# Primary: hooks-specific tests (functional + wiring + permissions)
./scripts/test-filter.sh hooks     # Expect: all pass

# MCP parity (deepwiki-context.py depends on MCP servers being configured)
./scripts/test-filter.sh mcp       # Expect: all pass

# Broader regression
./scripts/smoke-test.sh            # Note: setup.sh syntax error is pre-existing
./scripts/validate-macos.sh        # macOS-specific checks
```

**Known pre-existing issues** (not caused by hooks changes):
- `smoke-test.sh` fails on `setup.sh syntax valid` (line 1613 syntax error in setup.sh)
- `validate-macos.sh` exits early after OS detection (pre-existing incomplete checks)

---

## Debugging & Troubleshooting

### Debug Mode

```bash
claude --debug  # Full hook execution details
```

Toggle verbose mode in-session: `Ctrl+O`

### Common Issues

**Hook not firing:**
- Check `/hooks` menu for correct event registration
- Matchers are case-sensitive (`Bash` not `bash`)
- `UserPromptSubmit` and `Stop` ignore matchers
- `PermissionRequest` doesn't fire in headless mode (`-p`)

**Infinite Stop hook loop:**
Check `stop_hook_active` in your script:
```bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
    exit 0  # Allow stop
fi
```

**JSON parsing errors:**
Shell profile `echo` statements pollute stdout. Fix:
```bash
# In ~/.zshrc or ~/.bashrc
if [[ $- == *i* ]]; then
    echo "Shell ready"
fi
```

**Hook not taking effect after file edit:**
Hooks are snapshot'd at startup. Use `/hooks` menu to reload, or restart session.

### Testing Hooks Manually

```bash
# Pipe sample JSON to your hook script
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | python3 .claude/hooks/use_bun.py
echo $?  # Check exit code
```

---

## Best Practices

1. **Always handle errors gracefully**: Use `2>/dev/null || true` for non-critical hooks
2. **Use absolute paths**: Reference `$CLAUDE_PROJECT_DIR` for project scripts
3. **Quote shell variables**: Always `"$VAR"` not `$VAR`
4. **Set timeouts**: Prevent hanging hooks from blocking sessions
5. **Check `stop_hook_active`**: Prevent infinite loops in Stop hooks
6. **Use exit 2 for blocking**: Not exit 1 (which is non-blocking error)
7. **Keep SessionStart hooks fast**: They run on every session
8. **Use async for long tasks**: Tests, deployments, etc.
9. **Log to files, not stdout**: stdout goes to Claude's context
10. **Test manually before wiring**: Pipe sample JSON to verify behavior
