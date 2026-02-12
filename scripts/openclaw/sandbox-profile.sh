#!/usr/bin/env bash
# OpenClaw sandbox profile switcher for devcontainer sessions.
# Called by gwt-ticket/gwt-claude to relax sandbox when inside a devcontainer,
# and restore defaults on exit.
#
# Usage:
#   sandbox-profile.sh devcontainer   # Relax sandbox for coding
#   sandbox-profile.sh default        # Restore hardened defaults
#   sandbox-profile.sh show           # Show current profile

set -euo pipefail

CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"

if [[ ! -f "$CONFIG" ]]; then
    # Config doesn't exist yet — nothing to do
    exit 0
fi

if ! command -v jq &>/dev/null; then
    echo "jq required for sandbox profile switching" >&2
    exit 1
fi

profile="${1:-show}"

case "$profile" in
    devcontainer)
        # Relax sandbox for devcontainer coding sessions:
        # - workspaceAccess: rw (agent needs to edit code)
        # - docker.network: bridge (agent needs package installs)
        jq '.agents.defaults.sandbox.workspaceAccess = "rw" |
            .agents.defaults.sandbox.docker.network = "bridge"' \
            "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        echo "Sandbox profile: devcontainer (workspace=rw, network=bridge)"
        ;;
    default)
        # Restore hardened defaults
        jq '.agents.defaults.sandbox.workspaceAccess = "none" |
            .agents.defaults.sandbox.docker.network = "none"' \
            "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        echo "Sandbox profile: default (workspace=none, network=none)"
        ;;
    show)
        workspace=$(jq -r '.agents.defaults.sandbox.workspaceAccess // "unknown"' "$CONFIG")
        network=$(jq -r '.agents.defaults.sandbox.docker.network // "unknown"' "$CONFIG")
        echo "Sandbox: workspace=$workspace, network=$network"
        ;;
    *)
        echo "Usage: sandbox-profile.sh {devcontainer|default|show}" >&2
        exit 1
        ;;
esac
