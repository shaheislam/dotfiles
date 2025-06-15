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