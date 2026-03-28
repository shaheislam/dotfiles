---
name: freeze
description: Restrict ALL file edits to a single directory for the rest of this session. Prevents accidental changes outside the working scope.
argument-hint: "<directory>"
---

# Freeze Mode

Lock file edits to a single directory for the remainder of this session. Inspired by gstack's /freeze skill.

## Arguments

- `$ARGUMENTS` - Required: the directory path to restrict edits to.
  - Can be absolute (`/Users/shahe/dotfiles/.config/fish/`) or relative (`scripts/`)
  - If relative, resolve against the current working directory

## Activation

When invoked:

1. **Resolve the directory path** to an absolute path
2. **Verify the directory exists** — abort if it doesn't
3. **Confirm with the user**: "Freeze mode activated. All file edits restricted to: `<resolved_path>`. Use /unfreeze to remove this restriction."

## Behavior

For ALL subsequent file operations in this session:

### Allowed (within frozen directory):
- Read any file (Read tool) — no restrictions on reading
- Write files within the frozen directory
- Edit files within the frozen directory
- Create new files within the frozen directory
- Delete files within the frozen directory

### Blocked (outside frozen directory):
- Write to files outside the frozen directory
- Edit files outside the frozen directory
- Create new files outside the frozen directory
- Delete files outside the frozen directory

### When a blocked operation is attempted:

Display:

```
FREEZE MODE: Edit blocked

  Target:    [file path]
  Frozen to: [frozen directory]

  This file is outside the frozen directory.
  Use /unfreeze to remove the restriction, or move your work
  into the frozen directory.
```

Do NOT proceed with the operation.

### Exceptions

These operations are NEVER blocked, regardless of freeze:
- Reading any file (needed for context and understanding)
- Git operations (commit, push, etc.)
- Running tests or validation commands
- Package manager operations (brew, npm, pip)

## Notes

- Freeze mode is session-scoped — it ends when the session ends
- Only one freeze boundary can be active at a time
- Invoking /freeze again changes the frozen directory
- Use /unfreeze to remove the restriction
