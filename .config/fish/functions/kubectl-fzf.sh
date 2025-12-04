#!/usr/bin/env bash
# kubectl-fzf.sh - Bash helper for kubectl fzf completion
# Called from Fish to get proper TTY access for fzf (same pattern as fzf-git.sh)

set -euo pipefail

_kubectl_fzf() {
    fzf --height 50% --tmux 80%,60% \
        --layout reverse --multi \
        --bind 'tab:toggle+down,shift-tab:toggle+up' \
        --header 'TAB: select multiple, ENTER: confirm' \
        "$@"
}

case "${1:-}" in
    labels)
        # Get label completions
        resource_type="${2:-pods}"
        current="${3:-}"

        if [[ "$current" == *"="* ]]; then
            # Complete values for a key (e.g., "app=" -> "app=nginx", "app=redis")
            label_key="${current%%=*}"
            kubectl get "$resource_type" -A -o jsonpath="{.items[*].metadata.labels.$label_key}" 2>/dev/null \
                | tr ' ' '\n' \
                | sort -u \
                | grep -v '^$' \
                | while read -r val; do
                    echo "${label_key}=${val}"
                done \
                | _kubectl_fzf --prompt="Label value: " --query="${current#*=}"
        else
            # Complete keys (e.g., "" -> "app=", "tier=")
            {
                # Common labels first
                echo "app="
                echo "app.kubernetes.io/name="
                echo "app.kubernetes.io/instance="
                echo "app.kubernetes.io/component="
                echo "tier="
                echo "environment="
                echo "env="
                echo "release="
                echo "version="
                # Dynamic labels from cluster
                kubectl get "$resource_type" -A -o json 2>/dev/null \
                    | jq -r '.items[].metadata.labels // {} | keys[]' 2>/dev/null \
                    | sort -u \
                    | while read -r key; do
                        echo "${key}="
                    done
            } | sort -u | _kubectl_fzf --prompt="Label: " --query="$current"
        fi
        ;;
    *)
        echo "Usage: kubectl-fzf.sh labels [resource_type] [current]" >&2
        exit 1
        ;;
esac
