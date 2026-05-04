#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/aerospace/lib.sh
source "$script_dir/lib.sh"

aero_require

workspace="${1:-}"
preferred_focus_window_id="${2:-}"
if [[ -z "$workspace" ]]; then
    workspace=$(aerospace list-workspaces --focused 2>/dev/null || true)
fi

if ! aero_is_profile_workspace "$workspace"; then
    exit 0
fi

aero_acquire_lock "aerospace-workspace-layout-${workspace}" 40

focused_window_id=""
focused=$(aerospace list-windows --focused --format '%{window-id}|%{workspace}' 2>/dev/null || true)
if [[ -n "$focused" ]]; then
    IFS='|' read -r focused_window_id focused_workspace <<<"$focused"
    if [[ "$focused_workspace" != "$workspace" ]]; then
        focused_window_id=""
    fi
fi

if [[ -n "$preferred_focus_window_id" ]]; then
    focused_window_id="$preferred_focus_window_id"
fi

window_ids=()
window_pids=()
while IFS='|' read -r window_id app_pid app_id app_name; do
    if [[ -z "$window_id" ]]; then
        continue
    fi

    if aero_is_ignored_window "$app_id" "$app_name"; then
        continue
    fi

    window_ids+=("$window_id")
    if [[ -n "$app_pid" ]]; then
        window_pids+=("$app_pid")
    fi
done < <(aerospace list-windows --workspace "$workspace" --format '%{window-id}|%{app-pid}|%{app-bundle-id}|%{app-name}' 2>/dev/null || true)

if [[ "${#window_ids[@]}" -eq 0 ]]; then
    exit 0
fi

if [[ "$workspace" == "1" ]]; then
    for window_id in "${window_ids[@]}"; do
        aerospace fullscreen off --window-id "$window_id" >/dev/null 2>&1 || true
        aerospace macos-native-fullscreen --window-id "$window_id" off >/dev/null 2>&1 || true
        aerospace layout --window-id "$window_id" floating >/dev/null 2>&1 || true
    done

    sleep 0.1
    aero_resize_windows_for_pids "${window_pids[@]}"

    if [[ -n "$focused_window_id" ]]; then
        aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || focused_window_id=""
    fi

    if [[ -z "$focused_window_id" ]]; then
        focused_window_id="${window_ids[0]}"
        aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || true
    fi

    aero_resize_focused_window
    aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || true
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
    aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || focused_window_id=""
fi

if [[ -z "$focused_window_id" ]]; then
    aerospace focus --window-id "${window_ids[0]}" >/dev/null 2>&1 || true
fi
