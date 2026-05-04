#!/usr/bin/env bash
set -euo pipefail

if ! command -v aerospace >/dev/null 2>&1; then
    exit 0
fi

lock_dir="${TMPDIR:-/tmp}/aerospace-focus-layout.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$lock_dir"' EXIT

resize_focused_window() {
    osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "Finder"
    set desktopBounds to bounds of window of desktop
end tell

set {screenLeft, screenTop, screenRight, screenBottom} to desktopBounds
set screenWidth to screenRight - screenLeft
set screenHeight to screenBottom - screenTop
set targetWidth to (screenWidth * 0.92) as integer
set targetHeight to (screenHeight * 0.88) as integer
set targetLeft to (screenLeft + ((screenWidth - targetWidth) / 2)) as integer
set targetTop to (screenTop + ((screenHeight - targetHeight) / 2)) as integer

tell application "System Events"
    set frontProcess to first process whose frontmost is true
    tell frontProcess
        if (count of windows) is 0 then return
        set frontWindow to front window
        try
            set value of attribute "AXFullScreen" of frontWindow to false
        end try
        try
            perform action "AXRaise" of frontWindow
        end try
        set position of frontWindow to {targetLeft, targetTop}
        set size of frontWindow to {targetWidth, targetHeight}
    end tell
end tell
APPLESCRIPT
}

focused=$(aerospace list-windows --focused --format '%{window-id}|%{app-bundle-id}|%{app-name}|%{workspace}' 2>/dev/null || true)
if [[ -z "$focused" ]]; then
    exit 0
fi

IFS='|' read -r focused_window_id app_id app_name workspace <<<"$focused"

is_terminal=false
if [[ "$app_id" == "com.github.wez.wezterm" || "$app_name" =~ [Gg]hostty ]]; then
    is_terminal=true
fi

if [[ "$workspace" == "T" && "$is_terminal" == "true" ]]; then
    aerospace macos-native-fullscreen --window-id "$focused_window_id" off >/dev/null 2>&1 || true
    aerospace layout --window-id "$focused_window_id" tiling >/dev/null 2>&1 || true
    aerospace fullscreen on --window-id "$focused_window_id" --no-outer-gaps >/dev/null 2>&1 || true
    exit 0
fi

if [[ "$workspace" == "T" ]]; then
    target_workspace="1"
    state_file="${TMPDIR:-/tmp}/aerospace-active-layout-profile"
    if [[ -r "$state_file" ]]; then
        saved_workspace=$(<"$state_file")
        if [[ "$saved_workspace" =~ ^[1-4]$ ]]; then
            target_workspace="$saved_workspace"
        fi
    fi

    aerospace macos-native-fullscreen --window-id "$focused_window_id" off >/dev/null 2>&1 || true
    aerospace fullscreen off --window-id "$focused_window_id" >/dev/null 2>&1 || true
    aerospace move-node-to-workspace "$target_workspace" --focus-follows-window >/dev/null 2>&1 || exit 0
    /Users/shahe.islam/dotfiles/scripts/aerospace/apply-workspace-layout.sh "$target_workspace"
    exit 0
fi

if [[ "$workspace" != "1" ]]; then
    exit 0
fi

case "$app_id" in
    com.macosgame.iwallpaper)
        exit 0
        ;;
esac

case "$app_name" in
    MyWallpaper)
        exit 0
        ;;
esac

aerospace fullscreen off --window-id "$focused_window_id" >/dev/null 2>&1 || true
aerospace macos-native-fullscreen --window-id "$focused_window_id" off >/dev/null 2>&1 || true
aerospace layout --window-id "$focused_window_id" floating >/dev/null 2>&1 || true

if ! aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1; then
    exit 0
fi

resize_focused_window
