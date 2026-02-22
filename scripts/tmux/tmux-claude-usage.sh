#!/usr/bin/env bash
#
# tmux-claude-usage.sh - Compact Claude usage for tmux status bar
#
# Discovers profiles (default + ~/.claude-*/) and shows 5-hour utilization.
# Output: def:42 per:78 wrk:15 (profile:5h-pct)
# Empty output on total failure (hides powerkit pill).
#
# Caches API results for 5 minutes per profile at /tmp/tmux-claude-usage/

set -uo pipefail

CACHE_DIR="/tmp/tmux-claude-usage"
CACHE_TTL=300
USAGE_SCRIPT="$HOME/dotfiles/scripts/ticket-queue/claude-usage.sh"

mkdir -p "$CACHE_DIR"

cache_fresh() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    local now file_time
    now=$(date +%s)
    file_time=$(stat -f %m "$file" 2>/dev/null || echo 0)
    (((now - file_time) < CACHE_TTL))
}

get_usage_pct() {
    local profile="$1" config_dir="$2"
    local cache="$CACHE_DIR/$profile"

    if cache_fresh "$cache"; then
        cat "$cache"
        return 0
    fi

    local json
    if [[ -z "$config_dir" ]]; then
        json=$("$USAGE_SCRIPT" --json 2>/dev/null) || return 1
    else
        json=$("$USAGE_SCRIPT" --json --config-dir "$config_dir" 2>/dev/null) || return 1
    fi

    local pct
    pct=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(int(round(d.get('five_hour', {}).get('utilization', 0))))
" <<<"$json" 2>/dev/null) || return 1

    printf '%s' "$pct" >"$cache"
    echo "$pct"
}

results=()

# Default profile (Keychain credentials)
if pct=$(get_usage_pct "default" ""); then
    results+=("def:${pct}")
elif security find-generic-password -s "Claude Code-credentials" -w >/dev/null 2>&1; then
    results+=("def:?")
fi

# Named profiles (~/.claude-*/ with .credentials.json)
for dir in "$HOME"/.claude-*/; do
    [[ -d "$dir" && -f "$dir/.credentials.json" ]] || continue
    name=$(basename "$dir" | sed 's/^\.claude-//')
    short="${name:0:3}"
    if pct=$(get_usage_pct "$name" "$dir"); then
        results+=("${short}:${pct}")
    else
        results+=("${short}:?")
    fi
done

# Empty output hides the powerkit pill
[[ ${#results[@]} -eq 0 ]] && exit 0

# If every profile errored, hide the pill entirely
all_error=true
for r in "${results[@]}"; do
    [[ "$r" != *":?" ]] && {
        all_error=false
        break
    }
done
$all_error && exit 0

echo "${results[*]}"
