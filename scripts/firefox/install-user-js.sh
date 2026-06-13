#!/usr/bin/env bash
# install-user-js.sh — copy the managed user.js overlay into the active
# Firefox profile. Idempotent. Safe to re-run.
#
# Firefox reads user.js once at startup and merges values into prefs.js.
# Changes take effect on next Firefox launch (or quit + restart).
#
# Profile auto-discovery: prefers `*.default-release`, falls back to
# the most recently modified profile.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.config/firefox/user.js"
PROFILES="$HOME/Library/Application Support/Firefox/Profiles"

if [[ ! -f "$SRC" ]]; then
    echo "Source user.js missing: $SRC" >&2
    exit 1
fi

if [[ ! -d "$PROFILES" ]]; then
    echo "Firefox profile dir not found: $PROFILES" >&2
    exit 1
fi

# Prefer default-release, fall back to most recently modified.
PROFILE=$(find "$PROFILES" -maxdepth 1 -type d -name '*.default-release' | head -1)
if [[ -z "$PROFILE" ]]; then
    PROFILE=$(find "$PROFILES" -maxdepth 1 -mindepth 1 -type d \
        -exec stat -f '%m %N' {} + 2>/dev/null |
        sort -nr | head -1 | cut -d' ' -f2-)
fi

if [[ -z "$PROFILE" || ! -d "$PROFILE" ]]; then
    echo "Could not resolve a Firefox profile" >&2
    exit 1
fi

DEST="$PROFILE/user.js"
echo "Profile: $PROFILE"

if [[ -f "$DEST" ]] && cmp -s "$SRC" "$DEST"; then
    echo "user.js already up-to-date"
    exit 0
fi

if [[ -f "$DEST" ]]; then
    cp "$DEST" "$DEST.bak.$(date +%s)"
    echo "Existing user.js backed up"
fi

cp "$SRC" "$DEST"
echo "Installed: $DEST"
echo
echo "Restart Firefox for changes to take effect."
echo "Verify in about:config:"
grep -oE 'user_pref\("[^"]+"' "$DEST" | sed 's/user_pref("/  /; s/"$//'
