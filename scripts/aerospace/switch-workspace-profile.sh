#!/usr/bin/env bash
set -euo pipefail

if ! command -v aerospace >/dev/null 2>&1; then
    exit 0
fi

target_workspace="${1:-}"
case "$target_workspace" in
    1 | 2 | 3 | 4)
        ;;
    *)
        exit 0
        ;;
esac

lock_dir="${TMPDIR:-/tmp}/aerospace-profile-switch.lock"
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

state_file="${TMPDIR:-/tmp}/aerospace-active-layout-profile"
source_workspace=""
focused_window_id=""

focused=$(aerospace list-windows --focused --format '%{window-id}|%{workspace}' 2>/dev/null || true)
if [[ -n "$focused" ]]; then
    IFS='|' read -r focused_id focused_workspace <<<"$focused"
fi

case "${focused_workspace:-}" in
    1 | 2 | 3 | 4)
        source_workspace="$focused_workspace"
        focused_window_id="$focused_id"
        ;;
esac

if [[ -z "$source_workspace" && -r "$state_file" ]]; then
    saved_workspace=$(<"$state_file")
    case "$saved_workspace" in
        1 | 2 | 3 | 4)
            source_workspace="$saved_workspace"
            ;;
    esac
fi

if [[ -z "$source_workspace" ]]; then
    for candidate in 1 2 3 4; do
        count=$(aerospace list-windows --workspace "$candidate" --count 2>/dev/null || true)
        if [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
            source_workspace="$candidate"
            break
        fi
    done
fi

if [[ -n "$source_workspace" && "$source_workspace" != "$target_workspace" ]]; then
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

        aerospace move-node-to-workspace --window-id "$window_id" "$target_workspace" >/dev/null 2>&1 || true
    done < <(aerospace list-windows --workspace "$source_workspace" --format '%{window-id}|%{app-bundle-id}|%{app-name}' 2>/dev/null || true)
fi

aerospace workspace "$target_workspace" >/dev/null 2>&1 || exit 0
if [[ -n "$focused_window_id" ]]; then
    aerospace focus --window-id "$focused_window_id" >/dev/null 2>&1 || true
fi

printf '%s\n' "$target_workspace" >"$state_file"

/Users/shahe.islam/dotfiles/scripts/aerospace/apply-workspace-layout.sh "$target_workspace"
