---
name: commit-mode
description: Toggle automatic commit behavior (on/off)
argument-hint: on|off|status
---

# Commit Mode Toggle

Toggle automatic commit behavior for the current session.

## Arguments
- `on` - Enable auto-commits at natural breakpoints
- `off` - Disable auto-commits (require explicit requests)
- `status` - Show current mode

## Priority Order
1. **Session override**: This command (`/commit-mode on|off`)
2. **Project default**: `.claude/settings.json` with `{"autoCommit": true|false}`
3. **Global default**: OFF

## Behavior When ON
When auto-commit is enabled, commit at natural breakpoints:
- After completing a logical feature or bug fix
- After finishing a todo item that results in working code
- Before switching to a different area of the codebase
- When tests pass after a set of related changes

## Behavior When OFF (Default)
Only commit when the user explicitly asks (e.g., "commit this", "make a commit").

## Execution

First, check for project-level default by reading `.claude/settings.json` in the current
working directory. Look for `{"autoCommit": true}` or `{"autoCommit": false}`.

If $ARGUMENTS is "on":
  Acknowledge that auto-commit mode is now ENABLED for this session. Going forward,
  commit changes at natural breakpoints without asking. Follow existing git commit
  standards (no emojis, conventional format, no AI references).

If $ARGUMENTS is "off":
  Acknowledge that auto-commit mode is now DISABLED for this session. Only commit
  when explicitly requested by the user.

If $ARGUMENTS is "status" or empty:
  1. Check if `.claude/settings.json` exists and read `autoCommit` value
  2. Report both the project default (if any) and current session mode
  Example output:
  - "Project default: ON (from .claude/settings.json)"
  - "Session override: OFF"
  - "Effective mode: OFF"
