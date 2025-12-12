# CopyQ Clipboard Manager

CopyQ is a clipboard manager with advanced features including history, scripting, and automation. This documentation covers the power-user configuration included in these dotfiles.

## Installation

CopyQ is installed directly from GitHub releases (not Homebrew, which has deprecated the cask).

```bash
# Run the setup script - it will download and install CopyQ automatically
./scripts/setup/setup-copyq.sh
```

The setup script will:
1. Download CopyQ v13.0.0 from GitHub releases
2. Install to /Applications
3. Remove Gatekeeper quarantine
4. Import custom commands
5. Configure settings

### Manual Installation (if needed)

```bash
# Download from GitHub
curl -L "https://github.com/hluk/CopyQ/releases/download/v13.0.0/CopyQ-macos-12-m1.dmg.zip" -o /tmp/copyq.dmg.zip

# Extract and mount
unzip /tmp/copyq.dmg.zip -d /tmp
hdiutil attach /tmp/CopyQ-*.dmg

# Copy to Applications
cp -R "/Volumes/CopyQ/CopyQ.app" /Applications/

# Remove quarantine (bypass Gatekeeper)
xattr -cr /Applications/CopyQ.app

# Cleanup
hdiutil detach "/Volumes/CopyQ"
rm /tmp/copyq.dmg.zip /tmp/CopyQ-*.dmg
```

### Security Verification

The setup script performs these security checks before installation:

1. **SHA256 Checksum**: Verifies the download matches the official GitHub release
   - Prevents installation of corrupted or tampered binaries
   - Checksum: `2eb743cc57a97fde6c71d6ec0587408ae2beb41939699117d32b74e68882e77e`

2. **Ad-hoc Code Signing**: Required for macOS Sequoia (15.x)
   - CopyQ is not Apple-signed, so macOS blocks unsigned apps
   - Ad-hoc signing allows the verified binary to run
   - Only applied AFTER checksum verification passes

### Post-Installation

1. **Grant Accessibility access**: System Settings → Privacy & Security → Accessibility → Enable CopyQ
2. **First launch**: If you see a Gatekeeper warning, right-click CopyQ.app → Open

## Quick Start

1. **Open clipboard history**: `Cmd+Shift+V` (configured via Karabiner-Elements)
2. **Search history**: Just start typing when CopyQ window is open
3. **Paste item**: Click or press Enter on selected item
4. **Access via tmux**: `Ctrl+S + f` → select "clipboard"

## Keyboard Shortcuts

### Global Shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+V` | Open clipboard history (via Karabiner-Elements) |
| `Ctrl+1` | Paste item at position 1 |
| `Ctrl+2` | Paste item at position 2 |
| `Ctrl+3` | Paste item at position 3 |
| `Ctrl+4` | Paste item at position 4 |
| `Ctrl+5` | Paste item at position 5 |
| `Ctrl+Shift+C` | Queue item for sequential paste |
| `Ctrl+Shift+V` | Unqueue, paste, and Tab to next field |

### Paste Queue (Form Filling)

The paste queue lets you copy multiple items, then paste them sequentially into form fields:

1. **Queue items**: Copy each piece of data, then press `Ctrl+Shift+C` to add to queue
2. **Fill form**: Click the first field, then press `Ctrl+Shift+V` repeatedly
3. Each press pastes the next item and auto-Tabs to the next field

**Use cases:**
- Filling AWS console forms (region, account ID, resource name)
- Entering address fields (name, street, city, zip)
- Populating spreadsheet cells
- Any multi-field data entry

**View queue**: Open CopyQ (`Cmd+Shift+V`) → Click "Queue" tab

### DevOps Commands (In CopyQ Window)
| Shortcut | Action | Description |
|----------|--------|-------------|
| `Ctrl+J` | Format JSON | Pretty-print JSON using jq |
| `Ctrl+B` | Base64 Decode | Decode base64-encoded text |
| `Ctrl+Shift+B` | Base64 Encode | Encode text to base64 |
| `Ctrl+U` | URL Decode | Decode URL-encoded text |
| `Ctrl+Shift+U` | URL Encode | Encode text for URLs |
| `Ctrl+Alt+U` | Extract URLs | Pull all URLs from text |
| `Ctrl+Alt+A` | Parse AWS ARN | Break down ARN components |
| `Ctrl+Alt+J` | Decode JWT | Decode JWT payload |
| `Ctrl+Shift+A` | Strip ANSI | Remove terminal color codes |
| `Ctrl+Shift+T` | Trim Whitespace | Remove leading/trailing spaces |
| `Ctrl+D` | Insert Date/Time | Paste current timestamp |

### Right-Click Menu Commands
- Hash MD5
- Hash SHA256
- Sort Lines
- Sort Lines (Unique)
- Line Count
- Insert UUID

## Security Features

### Ignored Applications
The following applications are automatically ignored to prevent sensitive data from being stored:
- **1Password** - Password manager
- **Bitwarden** - Password manager
- **Keychain Access** - macOS keychain

### Blocked Patterns
AWS credentials are automatically detected and blocked:
- AWS Access Key IDs (pattern: `AKIA...`)
- Environment variables containing `aws_secret_access_key`
- Environment variables containing `AWS_SECRET_ACCESS_KEY`

When credentials are detected, you'll see a notification and the item won't be stored.

## Auto-Organization

Every clipboard item is automatically tagged with:
- **Source application** - The window title where you copied from
- **Timestamp** - When the item was copied

This helps you find items later (e.g., "I copied this from Slack around 3pm").

## Tmux Integration

CopyQ integrates with tmux via the existing tmux-fzf plugin:

1. Press `Ctrl+S + f` (tmux-fzf menu)
2. Select "clipboard"
3. Browse your clipboard history with FZF preview
4. Select an item to paste into the current tmux pane

## Configuration

### Import Commands Manually
```bash
copyq importCommands ~/.config/copyq/copyq-commands.ini
```

### Export Your Commands
```bash
copyq exportCommands > ~/my-copyq-commands.ini
```

### Common Settings via CLI
```bash
# Set max items in history
copyq config maxitems 1000

# Set number of items in tray menu
copyq config tray_items 20

# Enable paste on select
copyq config activate_pastes true

# Enable autostart
copyq config autostart true
```

## Scripting API

CopyQ uses JavaScript for scripting. Common functions:

```javascript
// Get clipboard text
var text = str(clipboard());

// Set clipboard
copy("new text");

// Paste to active window
paste();

// Show notification
popup("Title", "Message");

// Get current window title
var window = currentWindowTitle();

// Add item to history
add("text to add");

// Access item at row
var item = str(read(0)); // First item
```

## Troubleshooting

### CopyQ not starting automatically
1. Open CopyQ Preferences
2. Go to General tab
3. Enable "Run automatically on system startup"

### Global shortcut not working
The `Cmd+Shift+V` shortcut is configured via Karabiner-Elements (not CopyQ's native shortcuts).

1. **Ensure Karabiner-Elements is running**: Check menu bar for Karabiner icon
2. **Verify the rule is enabled**: Open Karabiner-Elements → Complex Modifications → Check "CopyQ: Cmd+Shift+V" is enabled
3. **Check CopyQ is running**: Look for CopyQ icon in menu bar
4. **Manual test**: Run `/Applications/CopyQ.app/Contents/MacOS/copyq toggle` in terminal

### Commands not appearing
```bash
# Re-import commands
copyq importCommands ~/.config/copyq/copyq-commands.ini

# Restart CopyQ
copyq exit
open -a CopyQ
```

### Password manager items still appearing
Ensure the window title regex matches. Check with:
```bash
# List active commands
copyq commands
```

The ignore commands use regex patterns like `.*1Password.*` - adjust if your window title differs.

## File Locations

| File | Location |
|------|----------|
| Commands config | `~/.config/copyq/copyq-commands.ini` |
| CopyQ data (macOS) | `~/Library/Application Support/CopyQ/` |
| Setup script | `~/dotfiles/scripts/setup/setup-copyq.sh` |

## Adding Custom Commands

1. Open CopyQ
2. Press `F6` or go to File → Commands/Global Shortcuts
3. Click "Add" → "New"
4. Configure:
   - **Name**: Descriptive name
   - **Command**: Your script (prefix with `bash:`, `python:`, or `copyq:`)
   - **Shortcut**: Keyboard shortcut (optional)
   - **Automatic**: Enable for clipboard-change triggers
   - **In Menu**: Show in right-click menu

### Example: Custom Command
```ini
[Command]
Name=Uppercase
Command=
    bash:
    echo "$COPYQ_ITEM_TEXT" | tr '[:lower:]' '[:upper:]'
Shortcut=ctrl+shift+u
Input=text/plain
Output=text/plain
InMenu=true
```

## Resources

- [CopyQ Documentation](https://copyq.readthedocs.io/en/latest/)
- [Scripting API Reference](https://copyq.readthedocs.io/en/latest/scripting-api.html)
- [Command Examples](https://copyq.readthedocs.io/en/latest/command-examples.html)
- [GitHub Repository](https://github.com/hluk/CopyQ)
