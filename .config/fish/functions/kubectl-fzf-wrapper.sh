#!/bin/bash
# kubectl FZF wrapper for interactive resource selection
# Provides fuzzy search with YAML preview and keyboard shortcuts
#
# Configurable via KUBECTL_FZF_OPTS environment variable
# Set in ~/.config/fish/config.fish for custom keybindings

RESOURCE="$1"
shift  # Remove first argument
EXTRA_ARGS="$*"

# Default keybindings (can be overridden via KUBECTL_FZF_OPTS)
DEFAULT_FZF_OPTS="
    --prompt='Select $RESOURCE: '
    --height=80%
    --border
    --preview='kubectl get {} -o yaml 2>/dev/null | bat --paging=never --style=numbers --color=always --language=yaml'
    --preview-window=right:60%
    --bind='ctrl-d:preview-page-down'
    --bind='ctrl-u:preview-page-up'
    --bind='ctrl-f:preview-down'
    --bind='ctrl-b:preview-up'
    --bind='ctrl-y:execute(kubectl get {} -o yaml 2>/dev/null | bat --paging=always --language=yaml)'
    --bind='ctrl-e:execute(kubectl describe {} 2>/dev/null | less)'
"

# Merge user options with defaults (user options override)
FZF_OPTS="${KUBECTL_FZF_OPTS:-$DEFAULT_FZF_OPTS}"

# Get the list and pipe to fzf with configured options
kubectl get "$RESOURCE" $EXTRA_ARGS -o name 2>/dev/null | \
    fzf $FZF_OPTS
