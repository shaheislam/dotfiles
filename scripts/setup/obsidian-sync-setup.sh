#!/bin/bash
# Setup script for Obsidian auto-commit system

VAULT_DIR="$HOME/obsidian"
HOOK_DIR="$VAULT_DIR/.git/hooks"

echo "🚀 Setting up Obsidian auto-commit system..."

# Check if we're in a git repository
if [ ! -d "$VAULT_DIR/.git" ]; then
    echo "❌ Error: Not a git repository at $VAULT_DIR"
    exit 1
fi

# Check for file watching tool (OS-aware)
if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS: use fswatch
    if ! command -v fswatch >/dev/null 2>&1; then
        echo "📦 Installing fswatch..."
        if command -v brew >/dev/null 2>&1; then
            brew install fswatch
        else
            echo "❌ Error: fswatch not installed and Homebrew not found"
            exit 1
        fi
    fi
    FILE_WATCHER="fswatch"
else
    # Linux: use inotify-tools (inotifywait)
    if ! command -v inotifywait >/dev/null 2>&1; then
        echo "📦 Installing inotify-tools..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y inotify-tools
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y inotify-tools
        elif command -v yum &> /dev/null; then
            sudo yum install -y inotify-tools
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm inotify-tools
        else
            echo "❌ Error: Cannot install inotify-tools automatically"
            echo "Please install inotify-tools manually"
            exit 1
        fi
    fi
    FILE_WATCHER="inotifywait"
    echo "ℹ️  Note: Using inotifywait instead of fswatch on Linux"
    echo "   The watcher script will need to be adapted for inotifywait syntax"
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOK_DIR"
mkdir -p "$HOOK_DIR/logs"

# Create the file watcher script
echo "🔧 Creating file watcher script..."
cat > "$HOOK_DIR/file-watcher.sh" << 'EOF'
#!/bin/bash
# Obsidian Git Auto-Commit Watcher

VAULT_DIR="$HOME/obsidian"
HOOK_DIR="$VAULT_DIR/.git/hooks"
LOG_FILE="$HOOK_DIR/logs/watcher.log"
STATUS_FILE="$HOOK_DIR/commit-status.json"

# Configuration
COMMIT_DELAY=5  # Seconds to wait after last change
PUSH_INTERVAL=600  # Push every 10 minutes
PUSH_COMMIT_THRESHOLD=5  # Push after 5 commits

# Track state
last_push_time=$(date +%s)
unpushed_commits=0
pending_files=""
last_change_time=0

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

update_status() {
    echo "{
  \"last_commit\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
  \"unpushed_commits\": $unpushed_commits,
  \"last_push\": \"$(date -r $last_push_time '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'Never')\"
}" > "$STATUS_FILE"
}

commit_changes() {
    cd "$VAULT_DIR" || return

    if [ -n "$(git status --porcelain)" ]; then
        # Stage all changes
        git add -A

        # Count changed files
        file_count=$(git status --porcelain | wc -l | tr -d ' ')

        # Generate commit message
        if [ "$file_count" -eq 1 ]; then
            file_name=$(git status --porcelain | cut -c4-)
            commit_msg="📝 Update: $file_name [$(date '+%H:%M')]"
        else
            commit_msg="📦 Update: $file_count files [$(date '+%H:%M')]"
        fi

        # Commit
        if git commit -m "$commit_msg" > /dev/null 2>&1; then
            log_message "Committed: $commit_msg"
            unpushed_commits=$((unpushed_commits + 1))
            update_status

            # Check if we should push
            current_time=$(date +%s)
            time_since_push=$((current_time - last_push_time))

            if [ $unpushed_commits -ge $PUSH_COMMIT_THRESHOLD ] || [ $time_since_push -ge $PUSH_INTERVAL ]; then
                push_changes
            fi
        fi
    fi
}

push_changes() {
    cd "$VAULT_DIR" || return

    log_message "Pushing $unpushed_commits commits..."

    if git push origin main > /dev/null 2>&1; then
        log_message "Successfully pushed $unpushed_commits commits"
        unpushed_commits=0
        last_push_time=$(date +%s)
        update_status
    else
        log_message "Push failed, will retry later"
    fi
}

# Main watcher loop
log_message "Watcher started"

# Initial status
update_status

# Watch for file changes
fswatch -r --exclude ".git" "$VAULT_DIR" | while read -r event; do
    current_time=$(date +%s)

    # Debounce - wait for COMMIT_DELAY seconds of inactivity
    last_change_time=$current_time

    # Schedule commit after delay
    (
        sleep $COMMIT_DELAY
        current_check=$(date +%s)
        time_diff=$((current_check - last_change_time))

        if [ $time_diff -ge $((COMMIT_DELAY - 1)) ]; then
            commit_changes
        fi
    ) &
done
EOF

chmod +x "$HOOK_DIR/file-watcher.sh"

# Create LaunchAgent for macOS (auto-start on login)
echo "🚀 Creating LaunchAgent for auto-start..."
PLIST_PATH="$HOME/Library/LaunchAgents/com.obsidian.git.watcher.plist"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.obsidian.git.watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOOK_DIR/file-watcher.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>WorkingDirectory</key>
    <string>$VAULT_DIR</string>
    <key>StandardOutPath</key>
    <string>$HOOK_DIR/logs/watcher.log</string>
    <key>StandardErrorPath</key>
    <string>$HOOK_DIR/logs/watcher.error.log</string>
    <key>ThrottleInterval</key>
    <integer>30</integer>
</dict>
</plist>
EOF

# Load the LaunchAgent
echo "✅ Loading LaunchAgent..."
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

# Update control scripts with correct paths
echo "📝 Updating control scripts..."

# Fix the status script
cat > "$VAULT_DIR/status-watcher.sh" << 'EOF'
#!/bin/bash
echo "🔍 Watcher Status:"
if launchctl list | grep -q com.obsidian.git.watcher; then
    echo "✅ Watcher is loaded"
    if pgrep -f "file-watcher.sh" > /dev/null; then
        echo "✅ Watcher is running (PID: $(pgrep -f file-watcher.sh))"
    else
        echo "⚠️  Watcher is loaded but not running"
    fi
else
    echo "❌ Watcher is not loaded"
fi

echo ""
echo "📡 Sync Status:"
cd ~/obsidian
git fetch origin main 2>/dev/null
local_hash=$(git rev-parse HEAD 2>/dev/null)
remote_hash=$(git rev-parse origin/main 2>/dev/null)

if [ "$local_hash" = "$remote_hash" ]; then
    echo "✅ In sync with upstream"
else
    unpushed=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
    unpulled=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")

    [ $unpushed -gt 0 ] && echo "📤 $unpushed commits to push"
    [ $unpulled -gt 0 ] && echo "📥 $unpulled commits to pull"
fi

echo ""
echo "📊 Recent commits:"
git log --oneline -3 --format="  %h %s [%ar]" 2>/dev/null

echo ""
echo "📝 Recent activity:"
if [ -f ~/obsidian/.git/hooks/logs/watcher.log ]; then
    tail -5 ~/obsidian/.git/hooks/logs/watcher.log 2>/dev/null
else
    echo "No recent activity"
fi
EOF

chmod +x "$VAULT_DIR/status-watcher.sh"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📚 Usage:"
echo "  • Status: cd ~/obsidian && ./status-watcher.sh"
echo "  • Logs:   tail -f ~/obsidian/.git/hooks/logs/watcher.log"
echo ""
echo "🎯 The watcher will:"
echo "  • Auto-commit changes after 5 seconds"
echo "  • Push after 5 commits or 10 minutes"
echo ""
echo "🚀 Starting watcher now..."
launchctl start com.obsidian.git.watcher

# Run status check
sleep 2
cd "$VAULT_DIR" && ./status-watcher.sh
