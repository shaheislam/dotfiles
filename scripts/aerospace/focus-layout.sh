#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/aerospace/lib.sh
source "$script_dir/lib.sh"

aero_require
aero_acquire_lock "aerospace-focus-layout"

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
    target_workspace=$(aero_active_profile 1)

    aerospace macos-native-fullscreen --window-id "$focused_window_id" off >/dev/null 2>&1 || true
    aerospace fullscreen off --window-id "$focused_window_id" >/dev/null 2>&1 || true
    aerospace move-node-to-workspace "$target_workspace" --focus-follows-window >/dev/null 2>&1 || exit 0
    "$script_dir/apply-workspace-layout.sh" "$target_workspace" "$focused_window_id"
    exit 0
fi

if [[ "$workspace" != "1" ]]; then
    exit 0
fi

if aero_is_ignored_window "$app_id" "$app_name"; then
    exit 0
fi

aerospace fullscreen off --window-id "$focused_window_id" >/dev/null 2>&1 || true
aerospace macos-native-fullscreen --window-id "$focused_window_id" off >/dev/null 2>&1 || true
aerospace layout --window-id "$focused_window_id" floating >/dev/null 2>&1 || true

current_focus=$(aerospace list-windows --focused --format '%{window-id}|%{workspace}' 2>/dev/null || true)
if [[ "$current_focus" != "$focused_window_id|$workspace" ]]; then
    exit 0
fi

aero_resize_focused_window
