---
title: aimux attach
description: Switch to a workspace's tmux window
---

## Usage

```bash
aimux attach [name]
```

**Alias:** `aimux a`

## Description

Switches to a workspace's tmux window. Without a name, opens an interactive fzf picker showing all tmux windows across all sessions. With a name, switches directly to the matching window.

## Options

| Flag | Description |
|------|-------------|
| `--help` / `-h` | Show help |

## Examples

```bash
# Interactive fzf picker (requires fzf)
aimux attach

# Switch to a specific workspace
aimux attach feature-auth

# Partial name matching
aimux attach auth
```

## What happens

### Without a name (fzf picker)

1. Requires `fzf` to be installed
2. Lists all tmux windows across all sessions with format: `session:window_index window_name pane_current_path`
3. Opens fzf with a prompt for interactive selection
4. If inside tmux: switches the client to the selected window
5. If outside tmux: attaches to the session containing the selected window

### With a name

1. Searches for a window matching the name in the current tmux session
2. If found: selects that window
3. If not found: searches all sessions for a matching window name
4. If found in another session: switches the client to that session/window
5. If not found anywhere: exits with an error

## Cross-session search

When you specify a name that does not match any window in your current session, aimux searches all tmux sessions. This means you can attach to a workspace created in a different session:

```bash
# Workspace created in session "dev"
# You are in session "main"
aimux attach feature-auth  # Switches to "dev" session automatically
```

## Without fzf

If `fzf` is not installed and no name is provided, aimux exits with a usage message:

```
error: Usage: aimux attach <name> (or install fzf for interactive picker)
```

Install fzf for the best experience:

```bash
brew install fzf
```

## Outside tmux

If you run `aimux attach` outside of a tmux session:

- With a name: attempts `tmux attach-session -t <name>` to attach to a session matching the name
- Without a name (fzf): selects a target and attaches to the session

## Notes

- The name matching uses `grep` so partial matches work (e.g., `auth` matches `feature-auth`)
- When multiple windows match, the first match is used
- The fzf picker shows all windows from all sessions, making it easy to navigate complex multi-session setups
