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

aero_is_profile_workspace() {
    [[ "$1" =~ ^[1-4]$ ]]
}

aero_state_file() {
    printf '%s/aerospace-active-layout-profile\n' "${TMPDIR:-/tmp}"
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

aero_resize_focused_window() {
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
