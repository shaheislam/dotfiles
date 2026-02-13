# Tmux Session Management Guide

## Overview
Your tmux setup uses a single, unified session manager that integrates tmux sessions, tmuxinator templates, and recent directories.

## Quick Reference

| Keybinding | Tool | Description |
|------------|------|-------------|
| `Ctrl-s + S` | Session Manager | Unified interface for all session management |

## Session Manager

**Location**: `~/dotfiles/scripts/tmux/tmux-session-manager.sh`

The session manager provides a unified interface with three types of entries:
- **[S]** - Existing tmux sessions with window count
- **[T]** - Tmuxinator project templates
- **[Z]** - Recently accessed directories (via zoxide)

### Features
- Large popup window (80% x 80%)
- Clear prefix notation for entry types
- Type any path to create a session in that directory
- Type a name to create a new named session
- Launch complex layouts via tmuxinator
- Quick access to recent directories
- Fast fuzzy search with fzf
- Supports tilde expansion for home directory

## Usage Examples

### Quick Session Switch
1. Press `Ctrl-s + S`
2. Type to filter existing sessions (marked with `[S]`)
3. Press Enter to switch

### Launch Tmuxinator Project
1. Press `Ctrl-s + S`
2. Select a `[T]` entry (tmuxinator template)
3. Press Enter to launch the full layout

### Create Session from Recent Directory
1. Press `Ctrl-s + S`
2. Select a `[Z]` entry (recent directory from zoxide)
3. Press Enter to create/switch to session

### Create Session from Any Path
1. Press `Ctrl-s + S`
2. Type a full path (e.g., `~/work/project` or `/usr/local/bin`)
3. Press Enter to create a session in that directory
   - Session name will be based on the directory name
   - Supports tilde expansion (`~` for home directory)

### Create New Named Session
1. Press `Ctrl-Space + S`
2. Type a session name (without slashes)
3. Press Enter to create a new session with that name

## Tmuxinator Templates

Pre-configured layouts available via tmuxinator:

### dotfiles
```yaml
name: dotfiles
root: ~/dotfiles
windows:
  - editor: nvim and testing pane
  - git: lazygit
  - shell: fish shell
  - logs: monitoring
```

### obsidian
```yaml
name: obsidian
root: ~/obsidian
windows:
  - editor: nvim
  - sync: git status monitoring
  - preview: markdown tools
```

### dev (template)
```yaml
name: dev
root: ~/projects/<project-name>
# Usage: tmuxinator start dev project-name
```

## Command Line Usage

```bash
# Tmuxinator commands
tmuxinator start dotfiles      # Launch dotfiles workspace
tmuxinator start obsidian      # Launch obsidian workspace
tmuxinator start dev myproject # Launch dev template with project name
tmuxinator list               # List all templates
tmuxinator new project-name   # Create new template
```

## Creating New Templates

To create a new tmuxinator template:
```bash
tmuxinator new project-name
# This opens ~/.config/tmuxinator/project-name.yml in your editor
```

Example template:
```yaml
name: myproject
root: ~/work/myproject

windows:
  - editor:
      layout: main-vertical
      panes:
        - nvim
        - # empty pane for commands
  
  - server:
      panes:
        - npm run dev
  
  - git:
      panes:
        - lazygit
```

## Session Close Behavior

When you close the last window of a session, tmux switches to the most recently active remaining session instead of detaching (which would close the terminal).

Four settings work together (tested with tmux 3.5a):

1. **`detach-on-destroy off`** (`.tmux.conf`): Switches to another session instead of detaching when a session is destroyed.
2. **`exit-empty off`** (`.tmux.conf`): Keeps the tmux server alive even when all sessions are briefly destroyed, giving hooks time to recreate `main`.
3. **Proactive + reactive `main` creation** (`.tmux.conf`): A `run-shell` ensures `main` exists at server start; a `session-closed` hook recreates it if destroyed.
4. **Non-exec auto-attach** (`config.fish`): `tmux new-session -A -s main` followed by `exit`. Fish is not replaced by tmux, so manual detach (`prefix+d`) returns to Fish which then exits cleanly. No nested shells.

Devcontainer and worktree sessions use distinct names (set by `gwt-ticket`) and are not affected by the `main` fallback hook.

### Terminal Hold-on-Exit (Optional Safety Net)

As defense-in-depth, terminal emulators can be configured to hold the tab open when the shell exits unexpectedly:

- **WezTerm**: `config.exit_behavior = "Hold"` in `wezterm.lua` (holds pane open on non-zero exit)
- **Ghostty**: `wait-after-command = true` in `~/.config/ghostty/config` (holds after process exits)

These are not currently enabled since the tmux-side fix handles all cases, but can be added as guardrails if needed.

## Reloading Configuration

`Ctrl-s + r` reloads the tmux config — **unless** the current pane is running Claude Code, in which case it triggers `recall` instead (context-aware binding).

To reload config when in a Claude pane:
- Switch to a non-Claude pane first, then `Ctrl-s + r`
- Or run `tmux source-file ~/.tmux.conf` directly in any shell pane

## Configuration Files

- **Tmux config**: `~/.tmux.conf`
- **Session manager script**: `~/dotfiles/scripts/tmux/tmux-session-manager.sh`
- **Tmuxinator configs**: `~/.config/tmuxinator/*.yml`

## Tips

- The session manager shows sessions first, then tmuxinator templates, then recent directories
- Session names are automatically cleaned (spaces and dots replaced with underscores)
- The `*` symbol indicates the currently attached session
- Use fuzzy search to quickly find what you need