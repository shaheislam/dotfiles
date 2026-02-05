# Claude Code Changelog Analysis (2.1.0 - 2.1.32)

> Reviewed: 2026-02-05
> Source: https://code.claude.com/docs/en/changelog

## TL;DR - High-Impact Changes

The most significant changes since this dotfiles repo was last updated:

1. **Claude Opus 4.6** is now the default model (2.1.32)
2. **Agent Teams** experimental multi-agent collaboration (2.1.32)
3. **Auto-memory** - Claude automatically records/recalls memories (2.1.32)
4. **Task management system** with dependency tracking (2.1.16)
5. **Customizable keybindings** (2.1.18)
6. **Merged slash commands and skills** into unified system (2.1.3)
7. **MCP tool search auto mode** enabled by default (2.1.7)
8. **npm deprecation** - installations moving away from npm (2.1.15)
9. **Security fixes** - command injection (2.1.2), shell bypass (2.1.6)

---

## Actionable Items for Dotfiles

### Must Update (Breaking/Deprecation)

| Version | Change | Impact | Action Required |
|---------|--------|--------|-----------------|
| 2.1.15 | npm installation deprecated | Setup script may need updating | Verify `setup.sh` install method uses recommended approach |
| 2.1.3 | Slash commands and skills merged | `.claude/skills/` now unified | No action - backwards compatible, but simplifies future skill creation |
| 2.1.7 | MCP tool search auto mode default | MCP `auto:N` syntax available | Consider adding `auto:` threshold config to setup |
| 2.1.20 | `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` | CLAUDE.md from `--add-dir` dirs | Useful for worktree setups; consider enabling |

### Should Configure (New Settings)

| Version | Setting | Purpose | Recommendation |
|---------|---------|---------|----------------|
| 2.1.32 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | Multi-agent collaboration | Experimental - monitor, don't enable yet |
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
| 2.1.32 | Auto-memory feature | Not configured | Works automatically, no config needed |
| 2.1.16 | Task management system | Not configured | Enable via `CLAUDE_CODE_ENABLE_TASKS` (default: true since 2.1.19) |
| 2.1.10 | Setup hook via `--init` | Not using | Consider for dotfiles-specific initialization |
| 2.1.30 | PDF `pages` parameter | N/A | Informational - Read tool now supports PDFs better |
| 2.1.2 | `FORCE_AUTOUPDATE_PLUGINS` | Not set | Consider adding to ensure plugins stay current |
| 2.1.6 | Release channel toggle | Not configured | Can use `/config` to switch stable/latest |

### Plugin Ecosystem Updates

| Version | Change | Impact |
|---------|--------|--------|
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

### Agent Teams (2.1.32) - Research Preview

Multi-agent collaboration where agents can work together on tasks. Requires:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```
This is experimental and not yet stable. Monitor for GA release before adding to setup.

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
1. Ensure Claude Code is updated to >= 2.1.32 (setup script should handle this)
2. Consider adding `FORCE_AUTOUPDATE_PLUGINS=1` to setup for auto-updating plugins
3. The `claude-opus-4-5-migration` plugin name is now slightly outdated since Opus 4.6 exists - monitor for a newer migration plugin

### Short-Term
1. Explore keybindings customization (`/keybindings`) and potentially add a `keybindings.json` to dotfiles
2. Test Agent Teams feature when it reaches stable
3. Review if `plansDirectory` setting would benefit the workflow

### No Action Needed
- Auto-memory works automatically
- Task system enabled by default
- MCP auto-search enabled by default
- Unified skills/commands backward compatible
- PDF support improvements work automatically

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
```
