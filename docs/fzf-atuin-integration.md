# FZF-Atuin History Search Integration

This configuration provides FZF-based fuzzy search for Atuin shell history in both Fish and Zsh shells, combining the best of both worlds: FZF's powerful fuzzy search interface with Atuin's superior history management and syncing capabilities.

## Features

- **Fuzzy Search**: Use FZF's excellent fuzzy matching algorithm to search through your shell history
- **Multi-mode Support**: Switch between directory, global, and session history modes on the fly
- **Consistent Interface**: Same keybindings and behavior across Fish and Zsh shells
- **Fast Performance**: Searches the last 5000 history entries by default (configurable)
- **Keybinding Compatibility**: Preserves native Atuin search on Ctrl-E while adding FZF search on Ctrl-R

## Installation

The integration is automatically set up when using the dotfiles setup script. Manual installation:

1. Ensure both `fzf` and `atuin` are installed:
   ```bash
   brew install fzf atuin
   ```

2. The configuration is automatically loaded from:
   - Fish: `~/.config/fish/config.fish`
   - Zsh: `~/.zshrc`

## Usage

### Primary Keybindings

- **Ctrl-R**: Open FZF-based Atuin history search (starts in directory mode)
- **Ctrl-E**: Open native Atuin search interface (for when you prefer the original)

### Within FZF Search

While in the FZF search interface, you can switch between different history modes:

- **Ctrl-D**: Directory mode - shows commands from current directory only
- **Ctrl-G**: Global mode - shows all commands from all directories
- **Ctrl-S**: Session mode - shows commands from current shell session
- **Ctrl-R**: Reload/refresh the current mode

### Fish-specific Keybindings

The Fish configuration also includes arrow key bindings for quick access to different Atuin modes:

- **Up Arrow**: Directory-filtered history (default Atuin behavior)
- **Left Arrow**: Session-filtered history
- **Right Arrow**: Global history

## Configuration

### Adjusting History Limit

By default, the FZF search shows the last 5000 history entries. To change this:

**Fish**: Edit the `fzf_atuin_history` function in `~/.config/fish/config.fish`:
```fish
set -l limit "--limit 10000"  # Change to desired value
```

**Zsh**: Edit the `fzf-atuin-history-widget` function in `~/.zshrc`:
```bash
local atuin_opts="--cmd-only --limit 10000"  # Change to desired value
```

### Customizing FZF Options

You can modify the FZF appearance and behavior by editing the `fzf_opts` in either shell configuration:

- Height: `--height=80%` (adjust percentage as needed)
- Layout: Add `--reverse` for top-down layout
- Preview: Add `--preview 'echo {}'` to show command preview

## Advantages Over Standard Approaches

1. **Better Fuzzy Search**: FZF's fuzzy matching is more flexible than Atuin's built-in search
2. **Familiar Interface**: If you're already using FZF for other tasks, this provides consistency
3. **Mode Switching**: Quickly switch between directory/global/session modes without leaving FZF
4. **Performance**: FZF is highly optimized for searching large datasets
5. **Customizable**: Leverage all of FZF's options and features

## Troubleshooting

### FZF search not working

1. Ensure both `fzf` and `atuin` are installed and in your PATH
2. Check that Atuin is properly initialized (run `atuin status`)
3. Verify the keybinding isn't conflicting with other tools

### Slow performance

1. Reduce the history limit (default 5000 entries)
2. Ensure you're using the latest versions of both tools
3. Check if Atuin database needs optimization: `atuin sync`

### Different behavior between shells

The implementations are designed to be as similar as possible, but some differences exist:
- Fish uses `commandline` for command manipulation
- Zsh uses `LBUFFER` for command buffer manipulation
- Fish has additional arrow key bindings

## Credits

This integration was inspired by the community discussion about combining FZF with Atuin, particularly the Zsh snippet shared on Hacker News that served as the foundation for this implementation.