---
name: guard
description: Maximum safety mode -- combines /careful (destructive command warnings) and /freeze (directory lock) for the session
argument-hint: "<directory>"
---

# Guard Mode

Activate maximum safety for this session by combining both /careful and /freeze. Inspired by gstack's /guard skill.

## Arguments

- `$ARGUMENTS` - Required: the directory path to restrict edits to (passed to /freeze)

## Activation

When invoked, activate BOTH safety modes:

1. **Invoke /careful** — Enable destructive command warnings (see careful/SKILL.md)
2. **Invoke /freeze $ARGUMENTS** — Restrict file edits to the specified directory (see freeze/SKILL.md)

Confirm:
```
Guard mode activated:
  Careful: ON — destructive commands will require confirmation
  Freeze:  ON — edits restricted to: <directory>

Both protections active for this session.
```

## Behavior

All rules from both /careful and /freeze apply simultaneously:
- Destructive commands require explicit confirmation
- File edits outside the frozen directory are blocked
- Reading files anywhere is unrestricted
- Git, test, and package operations are unrestricted

## Deactivation

- `/unfreeze` removes only the directory lock (careful mode stays active)
- There is no way to disable careful mode without starting a new session
- Guard mode is fully deactivated only when the session ends
