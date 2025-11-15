#!/bin/bash
# kubectl FZF wrapper for interactive resource selection
# Provides fuzzy search with YAML preview and keyboard shortcuts
#
# Configurable via KUBECTL_FZF_OPTS environment variable
# Set in ~/.config/fish/config.fish for custom keybindings

RESOURCE="$1"
shift  # Remove first argument
EXTRA_ARGS="$*"

# Default keybindings using bash array for proper FZF option handling
DEFAULT_FZF_OPTS=(
    --prompt="Select $RESOURCE: "
    --height=80%
    --border
    --preview="kubectl get {} -o yaml 2>/dev/null | bat --paging=never --style=numbers --color=always --language=yaml"
    --preview-window=right:60%
    --bind=ctrl-d:preview-page-down
    --bind=ctrl-u:preview-page-up
    --bind=ctrl-f:preview-down
    --bind=ctrl-b:preview-up
    --bind="ctrl-y:become(kubectl get {} -o yaml 2>/dev/null | bat --paging=always --language=yaml)"
    --bind="ctrl-e:become(kubectl describe {} 2>/dev/null | less)"
)

# Add user-defined options if set (KUBECTL_FZF_OPTS should be a space-separated string)
if [ -n "$KUBECTL_FZF_OPTS" ]; then
    # shellcheck disable=SC2206
    EXTRA_OPTS=($KUBECTL_FZF_OPTS)
    FZF_OPTS=("${DEFAULT_FZF_OPTS[@]}" "${EXTRA_OPTS[@]}")
else
    FZF_OPTS=("${DEFAULT_FZF_OPTS[@]}")
fi

# Explicitly export FZF_DEFAULT_OPTS as empty to prevent global bindings from overriding
export FZF_DEFAULT_OPTS=""

# Get the list and pipe to fzf with configured options
kubectl get "$RESOURCE" $EXTRA_ARGS -o name 2>/dev/null | \
    fzf "${FZF_OPTS[@]}"
