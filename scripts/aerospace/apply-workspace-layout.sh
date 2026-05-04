#!/usr/bin/env bash
set -euo pipefail

if ! command -v aerospace >/dev/null 2>&1; then
    exit 0
fi

workspace="${1:-}"
if [[ -z "$workspace" ]]; then
    workspace=$(aerospace list-workspaces --focused 2>/dev/null || true)
fi

case "$workspace" in
    1 | 2 | 3 | 4)
        ;;
    *)
        exit 0
        ;;
esac

lock_dir="${TMPDIR:-/tmp}/aerospace-workspace-layout-${workspace}.lock"
locked=false
for _ in {1..40}; do
    if mkdir "$lock_dir" 2>/dev/null; then
        locked=true
        break
    fi
    sleep 0.05
done

if [[ "$locked" != "true" ]]; then
    exit 0
fi
trap 'rmdir "$lock_dir"' EXIT

focused_window_id=""
focused=$(aerospace list-windows --focused --format '%{window-id}|%{workspace}' 2>/dev/null || true)
if [[ -n "$focused" ]]; then
    IFS='|' read -r focused_window_id focused_workspace <<<"$focused"
    if [[ "$focused_workspace" != "$workspace" ]]; then
        focused_window_id=""
    fi
fi

window_ids=()
while IFS='|' read -r window_id app_id app_name; do
    if [[ -z "$window_id" ]]; then
        continue
    fi

    case "$app_id" in
        com.macosgame.iwallpaper)
            continue
            ;;
    esac

    case "$app_name" in
        MyWallpaper)
            continue
            ;;
    esac

    window_ids+=("$window_id")
done < <(aerospace list-windows --workspace "$workspace" --format '%{window-id}|%{app-bundle-id}|%{app-name}' 2>/dev/null || true)

if [[ "${#window_ids[@]}" -eq 0 ]]; then
    exit 0
fi

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

if [[ "$workspace" == "1" ]]; then
    for window_id in "${window_ids[@]}"; do
        aerospace fullscreen off --window-id "$window_id" >/dev/null 2>&1 || true
        aerospace macos-native-fullscreen --window-id "$window_id" off >/dev/null 2>&1 || true
        aerospace layout --window-id "$window_id" floating >/dev/null 2>&1 || true
    done

    if [[ -n "$focused_window_id" ]]; then
        aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || true
    else
        aerospace focus --window-id "${window_ids[0]}" >/dev/null 2>&1 || true
    fi

    resize_focused_window
    exit 0
fi

for window_id in "${window_ids[@]}"; do
    aerospace fullscreen off --window-id "$window_id" >/dev/null 2>&1 || true
    aerospace macos-native-fullscreen --window-id "$window_id" off >/dev/null 2>&1 || true
    aerospace layout --window-id "$window_id" tiling >/dev/null 2>&1 || true
done

aerospace flatten-workspace-tree --workspace "$workspace" >/dev/null 2>&1 || true

case "$workspace" in
    2 | 3)
        aerospace layout --window-id "${window_ids[0]}" h_tiles >/dev/null 2>&1 || true
        ;;
    4)
        aerospace layout --window-id "${window_ids[0]}" v_tiles >/dev/null 2>&1 || true
        ;;
esac

if [[ "$workspace" == "3" && "${#window_ids[@]}" -ge 3 ]]; then
    # Produces: first pane on the left, remaining panes vertically stacked on the right.
    aerospace join-with --window-id "${window_ids[1]}" right >/dev/null 2>&1 || true

    for ((i = 3; i < ${#window_ids[@]}; i += 1)); do
        aerospace move --window-id "${window_ids[$i]}" left >/dev/null 2>&1 || true
    done
fi

aerospace balance-sizes --workspace "$workspace" >/dev/null 2>&1 || true

if [[ -n "$focused_window_id" ]]; then
    aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || true
else
    aerospace focus --window-id "${window_ids[0]}" >/dev/null 2>&1 || true
fi
