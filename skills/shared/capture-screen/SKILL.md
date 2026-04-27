---
name: capture-screen
description: Programmatic screenshot capture on macOS. Find window IDs with Swift CGWindowListCopyWindowInfo, control application windows via AppleScript, and capture with screencapture. Use when automating screenshots, capturing app windows for documentation, or building visual agent workflows.
argument-hint: "<app-name> [--output path.png] [--all] [--list]"
allowed-tools: Bash, Read, Write
---

# Capture Screen

Programmatic screenshot capture on macOS: find windows, control views, capture images.

## Arguments

- `$ARGUMENTS` - Options:
  - `<app-name>` - Application to capture (e.g., "Chrome", "Excel", "Finder")
  - `--output path.png` - Output file path (default: `/tmp/capture-TIMESTAMP.png`)
  - `--all` - Capture all windows of the target app
  - `--list` - List all visible windows without capturing

## Three-Step Workflow

```
1. Find Window  ->  Swift CGWindowListCopyWindowInfo  ->  numeric Window ID
2. Control View ->  AppleScript (osascript)           ->  activate, zoom, scroll
3. Capture      ->  screencapture -l <WID>            ->  PNG output
```

## Step 1: Get Window ID (Swift)

This is the ONLY reliable method on macOS. Do not use AppleScript window IDs.

```bash
# Find windows for a specific app
swift -e '
import CoreGraphics
let keyword = "APP_NAME"
let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let name = w[kCGWindowName as String] as? String ?? ""
    let wid = w[kCGWindowNumber as String] as? Int ?? 0
    if owner.localizedCaseInsensitiveContains(keyword) || name.localizedCaseInsensitiveContains(keyword) {
        print("WID=\(wid) | App=\(owner) | Title=\(name)")
    }
}
'
```

If `--list` was specified, list all windows:
```bash
swift -e '
import CoreGraphics
let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let name = w[kCGWindowName as String] as? String ?? ""
    let wid = w[kCGWindowNumber as String] as? Int ?? 0
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    if layer == 0 && !owner.isEmpty {
        print("WID=\(wid) | App=\(owner) | Title=\(name)")
    }
}
'
```

Parse the WID number from output for use with `screencapture -l`.

## Step 2: Control Window (AppleScript)

Bring the target window to front before capturing:

```bash
# Activate app (bring to front) - ALWAYS wrap with timeout
timeout 5 osascript -e 'tell application "APP_NAME" to activate'
sleep 1
```

**IMPORTANT**: Always use `timeout 5` with `osascript` - it hangs if the app isn't running.

### App-Specific Controls

**Excel** (full AppleScript support):
```bash
# Set zoom
timeout 5 osascript -e 'tell application "Microsoft Excel" to set zoom of active window to 120'
# Scroll to row
timeout 5 osascript -e 'tell application "Microsoft Excel" to set scroll row of active window to 45'
# Switch sheet
timeout 5 osascript -e 'tell application "Microsoft Excel" to activate object sheet "Sheet1" of active workbook'
```

**Any app** (basic):
```bash
# Bring specific window to front
timeout 5 osascript -e 'tell application "System Events" to tell process "APP_NAME" to perform action "AXRaise" of window 1'
```

## Step 3: Capture

```bash
# Capture specific window (silent, no shutter sound)
screencapture -x -l $WID output.png

# Verify capture
file output.png  # Should show "PNG image data, ..."
```

### Retina Display Note

On Retina Macs, output is 2x resolution. To get 1x:
```bash
sips --resampleWidth $DESIRED_WIDTH output.png --out output_1x.png
```

## Complete Capture Flow

Putting it all together:

```bash
APP="TARGET_APP"
OUTPUT="${OUTPUT_PATH:-/tmp/capture-$(date +%s).png}"

# 1. Activate the app
timeout 5 osascript -e "tell application \"$APP\" to activate"
sleep 1

# 2. Get window ID (first match)
WID=$(swift -e "
import CoreGraphics
let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? \"\"
    let wid = w[kCGWindowNumber as String] as? Int ?? 0
    if owner == \"$APP\" { print(wid); break }
}
")

if [ -z "$WID" ]; then
    echo "Error: No window found for $APP" >&2
    exit 1
fi

# 3. Capture
screencapture -x -l "$WID" "$OUTPUT"

echo "Captured: $OUTPUT (Window ID: $WID)"
file "$OUTPUT"
```

## Multi-Shot Workflow

To capture multiple views of the same app:

1. Open/activate the app
2. Get the window ID ONCE (re-fetch if app restarts)
3. For each view: control the app (scroll, switch tab) -> sleep 1 -> capture

```bash
# Example: capture 3 sections of a spreadsheet
for row in 1 50 100; do
    timeout 5 osascript -e "tell application \"Microsoft Excel\" to set scroll row of active window to $row"
    sleep 1
    screencapture -x -l $WID "section_row${row}.png"
done
```

## Known Limitations

| Method | Status | Notes |
|--------|--------|-------|
| Swift CGWindowListCopyWindowInfo | WORKS | Only reliable window ID source |
| `osascript` window id | FAILS | Returns AppleScript index, not CGWindowID |
| Python `import Quartz` | FAILS | PyObjC not in system Python |
| `System Events` -> `id of window` | FAILS | Error -1728, wrong ID format |

## Permissions

macOS may require Screen Recording permission for `screencapture` to capture other apps' windows. Check System Settings > Privacy & Security > Screen Recording.
