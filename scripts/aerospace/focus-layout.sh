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
terminal_workspace=$(aero_terminal_workspace)

is_terminal=false
if [[ "$app_id" == "com.github.wez.wezterm" || "$app_name" =~ [Gg]hostty ]]; then
    is_terminal=true
fi

if [[ "$workspace" == "$terminal_workspace" && "$is_terminal" == "true" ]]; then
    aero_clear_window_fullscreen "$focused_window_id"
    aerospace layout --window-id "$focused_window_id" tiling >/dev/null 2>&1 || true
    aerospace fullscreen on --window-id "$focused_window_id" --no-outer-gaps >/dev/null 2>&1 || true
    exit 0
fi

if [[ "$workspace" == "$terminal_workspace" ]]; then
    target_workspace=$(aero_active_profile 1)

    aero_clear_window_fullscreen "$focused_window_id"
    aerospace move-node-to-workspace "$target_workspace" --focus-follows-window >/dev/null 2>&1 || exit 0
    "$script_dir/apply-workspace-layout.sh" "$target_workspace" "$focused_window_id"
    exit 0
fi

active_profile=$(aero_active_profile 1)
active_visible_limit=$(aero_profile_visible_limit "$active_profile")
if [[ "$workspace" == "1" && "$active_visible_limit" -gt 0 ]]; then
    if aero_is_ignored_window "$app_id" "$app_name"; then
        exit 0
    fi

    aero_clear_window_fullscreen "$focused_window_id"
    aerospace move-node-to-workspace "$active_profile" --focus-follows-window >/dev/null 2>&1 || exit 0
    "$script_dir/apply-workspace-layout.sh" "$active_profile" "$focused_window_id"
    exit 0
fi

if [[ "$workspace" != "1" ]]; then
    exit 0
fi

if aero_is_ignored_window "$app_id" "$app_name"; then
    exit 0
fi

aero_set_window_floating "$focused_window_id"

current_focus=$(aerospace list-windows --focused --format '%{window-id}|%{workspace}' 2>/dev/null || true)
if [[ "$current_focus" != "$focused_window_id|$workspace" ]]; then
    exit 0
fi

aero_resize_focused_window
