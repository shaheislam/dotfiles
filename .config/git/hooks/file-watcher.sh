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
/opt/homebrew/bin/fswatch -r --exclude ".git" "$VAULT_DIR" | while read -r event; do
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
