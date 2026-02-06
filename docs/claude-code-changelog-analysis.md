# Claude Code Changelog Analysis (2.1.0 - 2.1.34)

> Reviewed: 2026-02-06 (updated from 2026-02-05 review)
> Source: https://code.claude.com/docs/en/changelog

## TL;DR - High-Impact Changes

The most significant changes since this dotfiles repo was last updated:

1. **Claude Opus 4.6** is now the default model (2.1.32)
2. **Agent Teams** experimental multi-agent collaboration (2.1.32), with tmux fixes (2.1.33)
3. **Auto-memory** - Claude automatically records/recalls memories (2.1.32), now with `memory` frontmatter for agents (2.1.33)
4. **New hook events**: `TeammateIdle` and `TaskCompleted` for multi-agent workflows (2.1.33)
5. **Agent tool restrictions**: `Task(agent_type)` syntax in agent frontmatter (2.1.33)
6. **Task management system** with dependency tracking (2.1.16)
7. **Customizable keybindings** (2.1.18)
8. **Merged slash commands and skills** into unified system (2.1.3)
9. **MCP tool search auto mode** enabled by default (2.1.7)
10. **npm deprecation** - installations moving away from npm (2.1.15)
11. **Security fixes** - command injection (2.1.2), shell bypass (2.1.6), sandbox bypass (2.1.34)

---

## Actionable Items for Dotfiles

### Must Update (Breaking/Deprecation)

| Version | Change | Impact | Action Required |
|---------|--------|--------|-----------------|
| 2.1.34 | Sandbox bypass fix for `excludedCommands` | Security: excluded commands could bypass Bash ask permission | Verify sandbox config doesn't rely on `autoAllowBashIfSandboxed` with excluded commands |
| 2.1.15 | npm installation deprecated | Setup script may need updating | Verify `setup.sh` install method uses recommended approach |
| 2.1.3 | Slash commands and skills merged | `.claude/skills/` now unified | No action - backwards compatible, but simplifies future skill creation |
| 2.1.7 | MCP tool search auto mode default | MCP `auto:N` syntax available | Consider adding `auto:` threshold config to setup |
| 2.1.20 | `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` | CLAUDE.md from `--add-dir` dirs | Useful for worktree setups; consider enabling |

### Should Configure (New Settings)

| Version | Setting | Purpose | Recommendation |
|---------|---------|---------|----------------|
| 2.1.33 | `memory` agent frontmatter | Persistent memory for agents (user/project/local scope) | **Add to custom agents** - enables agents to remember across sessions |
| 2.1.33 | `Task(agent_type)` in agent tools | Restrict which sub-agents an agent can spawn | Useful for tightly-scoped agents in `.claude/agents/` |
| 2.1.32 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | Multi-agent collaboration | **Already enabled** in setup.sh |
| 2.1.23 | `spinnerVerbs` | Customizable spinner text | Low priority - cosmetic |
| 2.1.9 | `plansDirectory` | Custom plan file location | Could set to `.claude/plans/` for consistency |
| 2.1.9 | `showTurnDuration` (2.1.7) | Hide turn duration messages | Personal preference |
| 2.1.5 | `CLAUDE_CODE_TMPDIR` | Custom temp directory | Useful for sandboxed environments |
| 2.1.4 | `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | Disable background tasks | Keep default (enabled) |
| 2.1.20 | `respectGitignore` | Per-project gitignore control | Default is fine |
| 2.1.0 | `language` | Response language config | Already using English, no change needed |

### Should Update in setup.sh

| Version | Change | Current State | Recommended Action |
|---------|--------|---------------|-------------------|
| 2.1.33 | `TeammateIdle` + `TaskCompleted` hook events | Not using | **Consider adding hooks** for tmux-claude-watcher integration with Agent Teams |
| 2.1.33 | Agent Teams tmux fix | Already using Agent Teams | **No action** - fixes tmux send/receive which was broken |
| 2.1.32 | Auto-memory feature | Not configured | Works automatically, no config needed |
| 2.1.16 | Task management system | Not configured | Enable via `CLAUDE_CODE_ENABLE_TASKS` (default: true since 2.1.19) |
| 2.1.10 | Setup hook via `--init` | Not using | Consider for dotfiles-specific initialization |
| 2.1.30 | PDF `pages` parameter | N/A | Informational - Read tool now supports PDFs better |
| 2.1.2 | `FORCE_AUTOUPDATE_PLUGINS` | Already set | ✅ Applied in previous review |
| 2.1.6 | Release channel toggle | Not configured | Can use `/config` to switch stable/latest |

### Plugin Ecosystem Updates

| Version | Change | Impact |
|---------|--------|--------|
| 2.1.33 | Plugin name added to skill descriptions + `/skills` menu | Better discoverability of which plugin provides which skill |
| 2.1.33 | `memory` frontmatter for agents | Agents can persist memory across sessions (user/project/local scope) |
| 2.1.33 | `Task(agent_type)` restriction syntax | Agents can restrict which sub-agents they spawn |
| 2.1.14 | Pin plugins to git commit SHAs | Can lock plugin versions for stability |
| 2.1.16 | VSCode native plugin management | VSCode users get native UI |
| 2.1.6 | Automatic skill discovery from nested `.claude/skills/` | Skills in subdirectories auto-discovered |
| 2.1.3 | Commands and skills unified | Simpler mental model going forward |
| 2.1.0 | Auto skill hot-reload | `.claude/skills/` changes detected automatically |
| 2.1.0 | `context: fork` for skills | Skills can run in forked sub-agent |

### MCP Server Improvements

| Version | Change | Impact on Setup |
|---------|--------|----------------|
| 2.1.30 | OAuth client credentials for MCP | Better auth for MCP servers |
| 2.1.9 | `auto:N` syntax for MCP tool search | Can set auto-enable threshold |
| 2.1.7 | MCP tool search auto mode default (10%) | Already enabled by default |
| 2.1.11 | Fixed excessive MCP connection requests | Performance improvement |
| 2.1.3 | Tool hook timeout 60s → 10 minutes | Longer-running hooks now possible |

---

## Feature Deep Dives

### Agent Teams Stabilization (2.1.33-34)

Agent Teams received critical fixes in 2.1.33-34:
- **2.1.33**: Fixed tmux send/receive for agent teammate sessions - this was a **blocker** for the tmux-based workflow documented in CLAUDE.md
- **2.1.34**: Fixed a crash when agent teams setting changed between renders
- **2.1.34**: Security fix - commands excluded from sandboxing could bypass Bash ask permission when `autoAllowBashIfSandboxed` was enabled

This setup already has Agent Teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json). The tmux fix in 2.1.33 is particularly significant since this dotfiles repo uses tmux as the primary display mode for Agent Teams.

### New Hook Events (2.1.33)

Two new hook events for multi-agent workflows:
- **`TeammateIdle`**: Fires when an agent teammate goes idle
- **`TaskCompleted`**: Fires when a task is marked completed

These could integrate with the existing `tmux-claude-watcher.sh` daemon to provide native hook-based idle detection instead of the current polling approach (every 3 seconds).

### Agent Memory Frontmatter (2.1.33)

Agents defined in `.claude/agents/` can now use the `memory` frontmatter field with scopes:
- `user` - persists per-user across all projects
- `project` - persists per-project
- `local` - persists locally (not committed)

This is useful for custom agents that need to remember context across sessions.

### Agent Tool Restrictions (2.1.33)

Agents can now restrict which sub-agents they spawn using `Task(agent_type)` syntax in the `tools` frontmatter. Example:
```yaml
tools:
  - Task(Explore)
  - Task(Plan)
  - Read
  - Grep
```
This enables creating tightly-scoped agents that can only delegate to specific agent types.

### Agent Teams (2.1.32) - Research Preview

Multi-agent collaboration where agents can work together on tasks. Requires:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```
Already enabled in this setup. The tmux fix in 2.1.33 makes this much more reliable.

### Auto-Memory (2.1.32)

Claude now automatically records and recalls memories as it works. This is the `.claude/` memory directory feature. Already compatible with this dotfiles setup since the `.claude/` directory structure is in place.

### Task Management (2.1.16)

New built-in task system with:
- `TaskCreate`, `TaskGet`, `TaskUpdate`, `TaskList` tools
- Dependency tracking (blocks/blockedBy)
- Status: pending → in_progress → completed
- Enabled by default since 2.1.19

This complements the existing `/todo` workflow in this dotfiles setup.

### Customizable Keybindings (2.1.18)

Configure keyboard shortcuts via `~/.claude/keybindings.json`:
- Per-context keybindings
- Chord sequences
- Run `/keybindings` to configure
- Docs: https://code.claude.com/docs/en/keybindings

### Unified Skills/Commands (2.1.3)

Slash commands and skills are now the same system:
- `.claude/skills/` files are auto-discovered
- Skills can specify `context: fork` for isolation
- `$ARGUMENTS[0]` syntax for indexed args (changed from `$ARGUMENTS.0`)
- Skills without permissions/hooks allowed without approval

### Key Bug Fixes Worth Noting

| Version | Fix | Relevance |
|---------|-----|-----------|
| 2.1.34 | **Security: sandbox bypass via `excludedCommands`** | Critical - `autoAllowBashIfSandboxed` could be bypassed |
| 2.1.33 | **Fixed agent teammate sessions in tmux** | Critical for Agent Teams + tmux workflow |
| 2.1.33 | Fixed extended thinking interrupted by new messages | Reliability for long-running agents |
| 2.1.33 | Fixed API proxy 404 fallback | Proxy users no longer get broken fallback |
| 2.1.33 | Fixed proxy env vars not applied to WebFetch (Node.js build) | Network reliability |
| 2.1.33 | Fixed `/resume` showing raw XML for slash command sessions | UX improvement |
| 2.1.31 | Fixed bash "Read-only file system" with sandbox | Devcontainer workflows |
| 2.1.30 | Fixed phantom "(no content)" text blocks (token waste) | Token efficiency |
| 2.1.30 | 68% memory reduction for `--resume` | Long sessions |
| 2.1.21 | Fixed auto-compact triggering too early | Related to `autoCompactEnabled` setting |
| 2.1.20 | Fixed agents ignoring user messages | Reliability |
| 2.1.14 | Fixed memory issues with parallel subagents | `gwt-parallel` workflows |
| 2.1.2 | **Security: command injection in bash** | Critical fix |
| 2.1.6 | **Security: shell line continuation bypass** | Critical fix |
| 2.1.0 | Security: sensitive data in debug logs | Data protection |

### Performance Improvements

| Version | Improvement |
|---------|-------------|
| 2.1.30 | 68% memory reduction for session resume (lazy loading) |
| 2.1.15 | React Compiler for UI rendering |
| 2.1.14 | Fixed memory leak in long sessions |
| 2.1.7 | Improved typing responsiveness |
| 2.1.23 | Improved terminal rendering performance |

---

## Recommendations Summary

### Immediate Actions
1. **Update Claude Code to >= 2.1.34** - critical security fix for sandbox bypass
2. ✅ `FORCE_AUTOUPDATE_PLUGINS=1` already applied from previous review
3. ✅ `claude-opus-4-5-migration` plugin already removed from previous review

### Short-Term (New from 2.1.33-34)
1. **Explore `TeammateIdle`/`TaskCompleted` hooks** - could replace polling in `tmux-claude-watcher.sh` with native event-driven detection
2. **Add `memory` frontmatter** to custom agents in `.claude/agents/` for cross-session persistence
3. **Consider `Task(agent_type)` restrictions** for agents that should only delegate to specific sub-agent types
4. **Add plugin names** to skill descriptions for better discoverability (auto-enabled in 2.1.33)

### Short-Term (Existing)
1. Explore keybindings customization (`/keybindings`) and potentially add a `keybindings.json` to dotfiles
2. Agent Teams tmux support is now fixed (2.1.33) - can rely on tmux display mode
3. Review if `plansDirectory` setting would benefit the workflow
4. **VSCode remote sessions** for OAuth users now available (2.1.33) - useful if using VSCode

### No Action Needed
- Auto-memory works automatically
- Task system enabled by default
- MCP auto-search enabled by default
- Unified skills/commands backward compatible
- PDF support improvements work automatically
- Agent Teams tmux fix applied automatically on update
- Improved API error messages (2.1.33) apply automatically

---

## Version Timeline

```
2.1.0  ──── Skills hot-reload, language setting, fork context
2.1.2  ──── SECURITY: command injection fix, clickable hyperlinks
2.1.3  ──── Merged commands/skills, release channel toggle
2.1.5  ──── CLAUDE_CODE_TMPDIR
2.1.6  ──── SECURITY: shell bypass fix, auto skill discovery
2.1.7  ──── MCP tool search auto mode, typing improvements
2.1.9  ──── plansDirectory, auto:N syntax, PreToolUse additionalContext
2.1.10 ──── Setup hook (--init), OAuth URL copy shortcut
2.1.14 ──── Bash autocomplete, plugin pinning, memory leak fix
2.1.15 ──── npm deprecation warning, React Compiler UI
2.1.16 ──── Task management system, VSCode plugin support
2.1.18 ──── Customizable keybindings
2.1.19 ──── CLAUDE_CODE_ENABLE_TASKS, $ARGUMENTS[0] syntax
2.1.20 ──── Task deletion, CLAUDE.md from --add-dir, PR URL to Slack
2.1.21 ──── Fixed auto-compact, improved tool preference
2.1.23 ──── spinnerVerbs, mTLS/proxy fix
2.1.27 ──── --from-pr flag, PR auto-linking
2.1.29 ──── saved_hook_context fix
2.1.30 ──── PDF pages param, OAuth for MCP, /debug, 68% memory reduction
2.1.31 ──── Session resume hint, sandbox fix, improved system prompts
2.1.32 ──── Opus 4.6, Agent Teams, auto-memory, skill budget scales
2.1.33 ──── Agent Teams tmux fix, TeammateIdle/TaskCompleted hooks, agent memory/tool restrictions
2.1.34 ──── SECURITY: sandbox bypass fix, Agent Teams crash fix
```
