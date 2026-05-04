#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/aerospace/lib.sh
source "$script_dir/lib.sh"

aero_require

target_workspace="${1:-}"
if ! aero_is_profile_workspace "$target_workspace"; then
    exit 0
fi

aero_acquire_lock "aerospace-profile-switch" 40

state_file=$(aero_state_file)
source_workspace=""
focused_window_id=""

focused=$(aerospace list-windows --focused --format '%{window-id}|%{workspace}' 2>/dev/null || true)
if [[ -n "$focused" ]]; then
    IFS='|' read -r focused_id focused_workspace <<<"$focused"
fi

if aero_is_profile_workspace "${focused_workspace:-}"; then
    source_workspace="$focused_workspace"
    focused_window_id="$focused_id"
fi

if [[ "$source_workspace" == "$target_workspace" ]]; then
    printf '%s\n' "$target_workspace" >"$state_file"
    if [[ "$target_workspace" != "1" ]]; then
        "$script_dir/apply-workspace-layout.sh" "$target_workspace" "$focused_window_id"
    fi
    exit 0
fi

if [[ -z "$source_workspace" && -r "$state_file" ]]; then
    saved_workspace=$(<"$state_file")
    if aero_is_profile_workspace "$saved_workspace"; then
        source_workspace="$saved_workspace"
    fi
fi

if [[ -z "$source_workspace" ]]; then
    while IFS= read -r candidate; do
        count=$(aerospace list-windows --workspace "$candidate" --count 2>/dev/null || true)
        if [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
            source_workspace="$candidate"
            break
        fi
    done < <(aero_profile_workspaces)
fi

source_workspaces=()
if [[ -n "$source_workspace" && "$source_workspace" != "$target_workspace" ]]; then
    source_workspaces+=("$source_workspace")
fi

if [[ "$target_workspace" != "1" && "$source_workspace" != "1" ]]; then
    source_workspaces+=("1")
fi

for workspace_to_move in "${source_workspaces[@]}"; do
    while IFS='|' read -r window_id app_id app_name; do
        if [[ -z "$window_id" ]]; then
            continue
        fi

        if aero_is_ignored_window "$app_id" "$app_name"; then
            continue
        fi

        aerospace move-node-to-workspace --window-id "$window_id" "$target_workspace" >/dev/null 2>&1 || true
    done < <(aerospace list-windows --workspace "$workspace_to_move" --format '%{window-id}|%{app-bundle-id}|%{app-name}' 2>/dev/null || true)
done

if [[ -z "$source_workspace" && "$target_workspace" == "1" ]]; then
    aerospace workspace "$target_workspace" >/dev/null 2>&1 || exit 0
fi

printf '%s\n' "$target_workspace" >"$state_file"

aerospace workspace "$target_workspace" >/dev/null 2>&1 || exit 0
if [[ -n "$focused_window_id" ]]; then
    aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || true
fi

if [[ -n "$focused_window_id" ]]; then
    "$script_dir/apply-workspace-layout.sh" "$target_workspace" "$focused_window_id"
else
    "$script_dir/apply-workspace-layout.sh" "$target_workspace"
fi
