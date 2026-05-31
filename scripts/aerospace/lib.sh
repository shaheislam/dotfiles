#!/usr/bin/env bash

aero_require() {
    if ! command -v aerospace >/dev/null 2>&1; then
        exit 0
    fi
}

aero_acquire_lock() {
    local lock_name="$1"
    local attempts="${2:-1}"
    local locked=false

    AERO_LOCK_DIR="${TMPDIR:-/tmp}/${lock_name}.lock"
    for ((attempt = 1; attempt <= attempts; attempt += 1)); do
        if mkdir "$AERO_LOCK_DIR" 2>/dev/null; then
            locked=true
            break
        fi

        if ((attempt < attempts)); then
            sleep 0.05
        fi
    done

    if [[ "$locked" != "true" ]]; then
        exit 0
    fi

    trap 'rmdir "$AERO_LOCK_DIR"' EXIT
}

aero_profile_workspaces() {
    printf '%s\n' 1 2 3
}

aero_is_profile_workspace() {
    case "${1:-}" in
        1 | 2 | 3)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

aero_terminal_workspace() {
    printf '%s\n' T
}

aero_profile_visible_limit() {
    case "${1:-}" in
        2)
            printf '%s\n' 2
            ;;
        3)
            printf '%s\n' 3
            ;;
        *)
            printf '%s\n' 0
            ;;
    esac
}

aero_state_file() {
    printf '%s/aerospace-active-layout-profile\n' "${TMPDIR:-/tmp}"
}

aero_mru_file() {
    local workspace="$1"

    printf '%s/aerospace-profile-%s-mru\n' "${TMPDIR:-/tmp}" "$workspace"
}

aero_list_contains() {
    local needle="$1"
    shift || true

    local item
    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

aero_window_id_in_list() {
    aero_list_contains "$@"
}

aero_order_mru_window_ids() {
    local workspace="$1"
    local focused_window_id="$2"
    shift 2

    local window_ids=("$@")
    local ordered_window_ids=()
    local mru_file
    local window_id

    if [[ -n "$focused_window_id" ]] && aero_window_id_in_list "$focused_window_id" "${window_ids[@]}"; then
        ordered_window_ids+=("$focused_window_id")
    fi

    mru_file=$(aero_mru_file "$workspace")
    if [[ -r "$mru_file" ]]; then
        while IFS= read -r window_id; do
            if [[ -z "$window_id" ]]; then
                continue
            fi

            if ! aero_window_id_in_list "$window_id" "${window_ids[@]}"; then
                continue
            fi

            if aero_window_id_in_list "$window_id" "${ordered_window_ids[@]}"; then
                continue
            fi

            ordered_window_ids+=("$window_id")
        done <"$mru_file"
    fi

    for window_id in "${window_ids[@]}"; do
        if aero_window_id_in_list "$window_id" "${ordered_window_ids[@]}"; then
            continue
        fi

        ordered_window_ids+=("$window_id")
    done

    if [[ "${#ordered_window_ids[@]}" -gt 0 ]]; then
        printf '%s\n' "${ordered_window_ids[@]}"
    fi
}

aero_write_mru_window_ids() {
    local workspace="$1"
    shift

    local mru_file
    mru_file=$(aero_mru_file "$workspace")

    : >"$mru_file"
    if [[ "$#" -gt 0 ]]; then
        printf '%s\n' "$@" >"$mru_file"
    fi
}

aero_active_profile() {
    local fallback="${1:-1}"
    local state_file
    local saved_workspace

    state_file=$(aero_state_file)
    if [[ -r "$state_file" ]]; then
        saved_workspace=$(<"$state_file")
        if aero_is_profile_workspace "$saved_workspace"; then
            printf '%s\n' "$saved_workspace"
            return
        fi
    fi

    printf '%s\n' "$fallback"
}

aero_is_ignored_window() {
    local app_id="$1"
    local app_name="$2"

    [[ "$app_id" == "com.macosgame.iwallpaper" || "$app_name" == "MyWallpaper" ]]
}

aero_clear_window_fullscreen() {
    local window_id="$1"

    aerospace fullscreen off --window-id "$window_id" >/dev/null 2>&1 || true
    aerospace macos-native-fullscreen --window-id "$window_id" off >/dev/null 2>&1 || true
}

aero_set_window_floating() {
    local window_id="$1"

    aero_clear_window_fullscreen "$window_id"
    aerospace layout --window-id "$window_id" floating >/dev/null 2>&1 || true
}

aero_set_window_tiling() {
    local window_id="$1"

    aero_clear_window_fullscreen "$window_id"
    aerospace layout --window-id "$window_id" tiling >/dev/null 2>&1 || true
}

aero_park_window() {
    local window_id="$1"
    local target_workspace="${2:-1}"

    aero_clear_window_fullscreen "$window_id"
    aerospace move-node-to-workspace --window-id "$window_id" "$target_workspace" >/dev/null 2>&1 || true
    aerospace layout --window-id "$window_id" floating >/dev/null 2>&1 || true
}

aero_resize_focused_window() {
    aero_resize_focused_window_to_ratio 0.92 0.88
}

aero_resize_terminal_window() {
    aero_resize_focused_window_to_ratio 0.75 0.72
}

aero_resize_focused_window_to_ratio() {
    local width_ratio="${1:-0.92}"
    local height_ratio="${2:-0.88}"

    osascript - "$width_ratio" "$height_ratio" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
set widthRatio to item 1 of argv as real
set heightRatio to item 2 of argv as real

tell application "Finder"
    set desktopBounds to bounds of window of desktop
end tell

set {screenLeft, screenTop, screenRight, screenBottom} to desktopBounds
set screenWidth to screenRight - screenLeft
set screenHeight to screenBottom - screenTop
set targetWidth to (screenWidth * widthRatio) as integer
set targetHeight to (screenHeight * heightRatio) as integer
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
end run
APPLESCRIPT
}

aero_resize_windows_for_pids() {
    if [[ "$#" -eq 0 ]]; then
        return
    fi

    osascript - "$@" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
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
        repeat with pidValue in argv
            try
                set targetProcess to first process whose unix id is (pidValue as integer)
                tell targetProcess
                    repeat with targetWindow in windows
                        set shouldResize to false
                        try
                            set shouldResize to ((value of attribute "AXSubrole" of targetWindow as text) is "AXStandardWindow")
                        end try
                        try
                            if (value of attribute "AXMinimized" of targetWindow as boolean) then set shouldResize to false
                        end try

                        if shouldResize then
                            try
                                set value of attribute "AXFullScreen" of targetWindow to false
                            end try
                            try
                                set position of targetWindow to {targetLeft, targetTop}
                                set size of targetWindow to {targetWidth, targetHeight}
                            end try
                        end if
                    end repeat
                end tell
            end try
        end repeat
    end tell
end run
APPLESCRIPT
}
