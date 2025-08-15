# tmux-continuum Debug Output Fix

## Issue
When loading tmux, random strings/debug output appears in the CLI due to a `set -x` debug line in the tmux-continuum plugin.

## Solution
Comment out or remove line 3 in `.tmux/plugins/tmux-continuum/continuum.tmux`:

```bash
# Change this:
set -x

# To this:
# set -x
```

## Location
File: `/Users/shaheislam/.tmux/plugins/tmux-continuum/continuum.tmux:3`

## Note
This is a modification to a git submodule, so the change won't be committed to the dotfiles repo. You'll need to apply this fix on each workstation.

## Additional Issues
If you still see color sequences like `10;rgb:7878/7c7c/999911;rgb:1a1a/1b1b/262610;rgb:7878/7c7c/999` when starting tmux, this might be:

1. **Terminal color queries**: Your terminal might be sending color capability queries
2. **Shell prompt issues**: Starship or other prompt tools outputting during tmux startup
3. **Other tmux plugins**: Check other plugins for debug output

### Quick Debug Steps:
1. Start tmux with: `tmux -f /dev/null` (bypass config)
2. If clean, gradually add back plugins to isolate the issue
3. Check if issue happens in different terminals (iTerm2, Terminal.app, etc.)
