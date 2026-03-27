#!/usr/bin/env bash
# SessionStart hook: fix plugin script permissions across all devices
# Marketplace repos don't set +x in git, causing permission denied errors
find "$HOME/.claude/plugins/marketplaces" -type f -name '*.sh' ! -perm -u+x -exec chmod +x {} + 2>/dev/null
exit 0
