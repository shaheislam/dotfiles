# tmux-powerkit Setup Guide

## Overview

tmux-powerkit is now configured in your `.tmux.conf` with Catppuccin Mocha theme to match your Tokyo Night aesthetic.

## Current Configuration

### Active Plugins

Your status bar now displays:

1. **Git** - Current branch and status indicators
2. **DateTime** - Time and date in format `HH:MM Day DD Mon`
3. **CPU** - CPU usage percentage
4. **Memory** - RAM usage percentage
5. **Disk** - Disk usage
6. **Bandwidth** - Network bandwidth monitoring
7. **WiFi** - WiFi connection status and signal strength

### Theme

- **Theme**: Catppuccin
- **Variant**: Mocha (Tokyo Night color scheme)
- **Separator**: Rounded style
- **Update Interval**: 10 seconds

## Layout Explanation

### Two-Section vs Three-Section Layout

**Current Configuration (2-element)**:
```bash
set -g @powerkit_status_order "session,plugins"
```

This creates: **Session+Windows (left, seamless) | Plugins (right)**

- ✅ **No gap** between session and windows
- Session and windows flow together on the left side
- Plugin pills on the right side

**Three-Section Layout (creates gaps)**:
```bash
set -g @powerkit_status_order "session,windows,plugins"
```

This creates: **Session (left) | Windows (centered) | Plugins (right)**

- ⚠️ **Gap on both sides** of windows (because windows are centered)
- Useful if you want windows prominently centered

### Why the Gap Existed

The `@powerkit_elements_spacing "false"` setting removes spacing **within** sections (between plugin pills), but when using a 3-element order, PowerKit **centers** the middle element, creating gaps between the three sections. This is by design.

## Customization

### Adding/Removing Plugins

Edit the `@powerkit_plugins` line in `.tmux.conf`:

```bash
set -g @powerkit_plugins "git,datetime,cpu,memory,disk,bandwidth,wifi"
```

### Available Plugins

#### System Monitoring (12)
- `battery` - Battery level and charging status
- `cpu` - CPU usage percentage
- `memory` - RAM usage
- `disk` - Disk usage
- `load` - System load average
- `temperature` - System temperature
- `fan` - Fan speed
- `gpu` - GPU usage
- `io` - I/O operations
- `brightness` - Screen brightness
- `uptime` - System uptime
- `hostname` - Machine hostname

#### Network (7)
- `bandwidth` - Network bandwidth monitoring
- `wifi` - WiFi status and signal
- `vpn` - VPN connection status
- `latency` - Network latency
- `public_ip` - Public IP address
- `ssh` - SSH connection indicator
- `weather` - Weather information

#### Media (7)
- `volume` - System volume level
- `now_playing` - Currently playing media
- Audio device indicators
- Camera/microphone status
- Bluetooth status

#### Development (10)
- `git` - Git branch and status
- `github` - GitHub notifications
- `gitlab` - GitLab notifications
- `bitbucket` - Bitbucket notifications
- `jira` - Jira issues
- `kubernetes` - K8s context
- `terraform` - Terraform workspace
- `cloud` - Cloud provider profile
- `packages` - Package updates

#### Productivity (5)
- `datetime` - Date and time
- Timezone information
- `pomodoro` - Pomodoro timer
- `bitwarden` - Bitwarden vault status
- `env` - Custom environment variables

#### Financial (2)
- `crypto` - Cryptocurrency prices
- `stocks` - Stock prices

### Changing Theme

Available themes include:
- `catppuccin` (variants: latte, frappe, macchiato, mocha)
- `tokyo-night` (variants: night, storm, day)
- `nord`
- `dracula`
- `gruvbox`
- And 35+ more!

To change theme:

```bash
set -g @powerkit_theme "tokyo-night"
set -g @powerkit_theme_variant "night"
```

### Changing Separator Style

Available styles:
- `normal` - Simple separators
- `rounded` - Rounded separators (current)
- `slant` - Slanted separators
- `flame` - Flame-like separators
- `pixel` - Pixelated separators
- `honeycomb` - Honeycomb pattern

```bash
set -g @powerkit_separator_style "slant"
```

### Plugin-Specific Settings

```bash
# DateTime format
set -g @powerkit_datetime_format "%H:%M %a %d %b"

# Git settings
set -g @powerkit_git_show_branch true
set -g @powerkit_git_show_status true

# Network interface
set -g @powerkit_bandwidth_interface "auto"  # or "en0", "eth0", etc.

# WiFi signal
set -g @powerkit_wifi_show_signal true
```

## Reverting to Minimal Setup

If you want to go back to your minimal status bar:

1. Comment out or remove the `tmux-powerkit` plugin line:
   ```bash
   # set -g @plugin 'fabioluciano/tmux-powerkit'
   ```

2. Uncomment the minimal status bar configuration (lines 227-263 in `.tmux.conf`)

3. Reload tmux: `Ctrl-s + r`

## Applying Changes

After making changes to `.tmux.conf`:

1. Reload configuration: `Ctrl-s + r`
2. If you added/removed plugins, install them: `Ctrl-s + I` (capital I)
3. Update plugins: `Ctrl-s + U` (capital U)

## Resources

- [tmux-powerkit GitHub](https://github.com/fabioluciano/tmux-powerkit)
- [Available Themes](https://github.com/fabioluciano/tmux-powerkit/tree/main/themes)
- [Plugin Documentation](https://github.com/fabioluciano/tmux-powerkit/tree/main/plugins)

## Troubleshooting

### Status bar not showing
- Ensure tmux is running
- Reload config: `Ctrl-s + r`
- Check for errors: `tmux source-file ~/.tmux.conf`

### Plugins not working
- Install plugins: `Ctrl-s + I`
- Check plugin requirements (some need additional tools)
- Review plugin logs: `~/.tmux/plugins/tmux-powerkit/`

### Performance issues
- Increase update interval:
  ```bash
  set -g @powerkit_update_interval 30  # Update every 30 seconds
  ```
- Disable resource-intensive plugins (weather, crypto, stocks)
