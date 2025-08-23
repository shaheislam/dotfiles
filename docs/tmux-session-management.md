# Tmux Session Management Guide

## Overview
Your tmux setup includes multiple session management tools, each optimized for different workflows.

## Quick Reference

| Keybinding | Tool | Description |
|------------|------|-------------|
| `Ctrl-Space + T` | Enhanced Wizard | Sessions + Tmuxinator + Zoxide (recommended) |
| `Ctrl-Space + S` | Session Manager | Alternative view with compact display |
| `Ctrl-Space + o` | tmux-sessionx | Fast session switcher (no preview) |
| `Ctrl-Space + W` | Original Wizard | Basic session wizard without tmuxinator |

## Tools Breakdown

### Enhanced Session Wizard (`Ctrl-Space + T`)
**Location**: `~/dotfiles/scripts/tmux-wizard-enhanced.sh`

The primary session management tool that combines:
- **[SESSION]** - Existing tmux sessions with window count
- **[TMUXINATOR]** - Pre-configured project templates
- **[ZOXIDE]** - Recently accessed directories

**Features**:
- Unified interface with clear labels
- Create new sessions by typing a name
- Launch complex layouts via tmuxinator
- Quick access to recent directories

### Session Manager (`Ctrl-Space + S`)
**Location**: `~/dotfiles/scripts/tmux-session-manager.sh`

Alternative interface with:
- **[S]** - Sessions (compact view)
- **[T]** - Tmuxinator templates
- **[Z]** - Zoxide directories

**Features**:
- Larger popup window (80% x 80%)
- Compact prefix notation
- Same functionality, different view

### tmux-sessionx (`Ctrl-Space + o`)
**Location**: Plugin at `~/.tmux/plugins/tmux-sessionx`

Fast session switcher optimized for performance:
- No preview for faster loading
- Tree mode disabled by default
- Custom paths limited to essential directories
- Tmuxinator integration enabled

### Original Session Wizard (`Ctrl-Space + W`)
**Location**: Plugin at `~/.tmux/plugins/tmux-session-wizard`

Basic session management without tmuxinator integration.

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

## Usage Examples

### Quick Session Switch
1. Press `Ctrl-Space + T`
2. Type to filter existing sessions
3. Press Enter to switch

### Launch Tmuxinator Project
1. Press `Ctrl-Space + T`
2. Select a `[TMUXINATOR]` entry
3. Press Enter to launch the full layout

### Create Session from Directory
1. Press `Ctrl-Space + T`
2. Select a `[ZOXIDE]` directory
3. Press Enter to create/switch to session

### Create New Session
1. Press `Ctrl-Space + T`
2. Type a new session name
3. Press Enter to create

## Command Line Usage

```bash
# Tmuxinator commands
tmuxinator start dotfiles      # Launch dotfiles workspace
tmuxinator start obsidian      # Launch obsidian workspace
tmuxinator start dev myproject # Launch dev template with project name
tmuxinator list               # List all templates
tmuxinator new project-name   # Create new template
```

## Performance Optimization

The sessionx plugin (`Ctrl-Space + o`) is configured for speed:
- Preview disabled: `@sessionx-preview-enabled 'false'`
- Tree mode off: `@sessionx-tree-mode 'off'`
- Limited custom paths: Only essential directories
- Zoxide mode enabled for recent directories

## Troubleshooting

### Sessions Not Showing
- The scripts include proper PATH setup for homebrew
- All commands use standard paths (`/opt/homebrew/bin`)
- tmux server connection is automatic

### Slow Performance
- Use `Ctrl-Space + o` (sessionx) for fastest switching
- Preview and tree modes are disabled by default
- Large directories are excluded from custom paths

### Creating New Templates
```bash
tmuxinator new project-name
# Edit ~/.config/tmuxinator/project-name.yml
```

## Configuration Files

- **Tmux config**: `~/.tmux.conf`
- **Enhanced wizard**: `~/dotfiles/scripts/tmux-wizard-enhanced.sh`
- **Session manager**: `~/dotfiles/scripts/tmux-session-manager.sh`
- **Tmuxinator configs**: `~/.config/tmuxinator/*.yml`