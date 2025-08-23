#!/bin/bash

# Tmux Session Trash System
# Automatically saves sessions before they're killed and provides recovery

# Configuration
RESURRECT_DIR="$HOME/.tmux/resurrect"
TRASH_DIR="$RESURRECT_DIR/trash"
MAX_TRASH_ITEMS=10
RESURRECT_SAVE_SCRIPT="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"

# Ensure trash directory exists
mkdir -p "$TRASH_DIR"

# Function to save a session to trash
save_to_trash() {
    local session_name="$1"
    [ -z "$session_name" ] && exit 0
    
    # Generate timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local trash_file="${TRASH_DIR}/${session_name}_${timestamp}.txt"
    
    # Check if session exists
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        exit 0
    fi
    
    # Save the current state using resurrect's save script
    if [ -x "$RESURRECT_SAVE_SCRIPT" ]; then
        # Run the resurrect save script
        TMUX="" tmux run-shell "$RESURRECT_SAVE_SCRIPT"
        
        # Copy the last resurrect save to trash with our naming
        local last_save=$(ls -t "$RESURRECT_DIR"/tmux_resurrect_*.txt 2>/dev/null | head -1)
        if [ -f "$last_save" ]; then
            cp "$last_save" "$trash_file"
            echo "Session '$session_name' saved to trash"
        fi
    fi
    
    # Clean old trash items
    clean_trash
}

# Function to clean old trash items (keep only MAX_TRASH_ITEMS most recent)
clean_trash() {
    local count=$(ls -1 "$TRASH_DIR"/*.txt 2>/dev/null | wc -l)
    if [ "$count" -gt "$MAX_TRASH_ITEMS" ]; then
        local to_delete=$((count - MAX_TRASH_ITEMS))
        ls -t "$TRASH_DIR"/*.txt | tail -n "$to_delete" | xargs rm -f
    fi
}

# Function to restore from trash
restore_from_trash() {
    # Check if fzf is available
    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is required for interactive restore"
        exit 1
    fi
    
    # Check if there are any trash files
    if [ -z "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]; then
        echo "No sessions in trash"
        exit 0
    fi
    
    # Preview command for fzf
    local preview_cmd='
        FILE="{}"
        echo "📋 Session Backup Details"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Extract session info from filename
        BASENAME=$(basename "$FILE" .txt)
        SESSION_NAME=$(echo "$BASENAME" | sed "s/_[0-9]*_[0-9]*$//")
        TIMESTAMP=$(echo "$BASENAME" | grep -oE "[0-9]+_[0-9]+$")
        
        # Format timestamp
        if [ -n "$TIMESTAMP" ]; then
            DATE_PART=$(echo "$TIMESTAMP" | cut -d_ -f1)
            TIME_PART=$(echo "$TIMESTAMP" | cut -d_ -f2)
            FORMATTED_DATE=$(date -j -f "%Y%m%d" "$DATE_PART" "+%Y-%m-%d" 2>/dev/null || echo "$DATE_PART")
            FORMATTED_TIME=$(echo "$TIME_PART" | sed "s/\(..\)\(..\)\(..\)/\1:\2:\3/")
            echo "Session: $SESSION_NAME"
            echo "Killed: $FORMATTED_DATE at $FORMATTED_TIME"
        else
            echo "Session: $SESSION_NAME"
        fi
        
        echo ""
        echo "📄 Saved State:"
        echo "───────────────────────────────────────"
        
        # Show session structure from the file
        if [ -f "$FILE" ]; then
            # Extract pane information
            grep "^pane" "$FILE" | head -10 | while read line; do
                # Parse pane info (format: pane <session> <window> <command>)
                PANE_INFO=$(echo "$line" | cut -d" " -f2-)
                echo "  $PANE_INFO"
            done
            
            echo ""
            echo "Windows and panes saved in this backup:"
            grep "^window" "$FILE" | wc -l | xargs echo "  Windows:"
            grep "^pane" "$FILE" | wc -l | xargs echo "  Panes:"
        fi
    '
    
    # Select trash file to restore
    local selected=$(ls -t "$TRASH_DIR"/*.txt 2>/dev/null | \
        fzf --reverse \
            --header "Select session to restore from trash (ESC to cancel)" \
            --preview "bash -c '$preview_cmd'" \
            --preview-window="right:50%:wrap" \
            --height=100%)
    
    if [ -n "$selected" ] && [ -f "$selected" ]; then
        # Extract session name from filename
        local basename=$(basename "$selected" .txt)
        local session_name=$(echo "$basename" | sed 's/_[0-9]*_[0-9]*$//')
        
        # Check if session already exists
        if tmux has-session -t "$session_name" 2>/dev/null; then
            echo "Session '$session_name' already exists. Restore with a different name? (y/n)"
            read -r response
            if [[ "$response" != "y" ]]; then
                exit 0
            fi
            echo "Enter new session name:"
            read -r new_name
            session_name="$new_name"
        fi
        
        # Restore using resurrect's restore script
        local restore_script="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
        if [ -x "$restore_script" ]; then
            # Copy the trash file as the resurrect save file to restore from
            cp "$selected" "$RESURRECT_DIR/last"
            
            # Use tmux-resurrect keybinding to restore
            echo "Restoring session from trash..."
            tmux send-keys -t $TMUX_PANE C-Space C-r
            
            echo ""
            echo "✅ Session restoration triggered!"
            echo ""
            echo "Remove from trash? (y/n)"
            read -r response
            if [[ "$response" == "y" ]]; then
                rm "$selected"
                echo "Removed from trash"
            fi
        else
            echo "Error: tmux-resurrect restore script not found"
            exit 1
        fi
    fi
}

# Function to list trash contents
list_trash() {
    if [ -z "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]; then
        echo "Trash is empty"
        return
    fi
    
    echo "Sessions in trash (newest first):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    ls -t "$TRASH_DIR"/*.txt 2>/dev/null | while read file; do
        local basename=$(basename "$file" .txt)
        local session_name=$(echo "$basename" | sed 's/_[0-9]*_[0-9]*$//')
        local timestamp=$(echo "$basename" | grep -oE '[0-9]+_[0-9]+$')
        
        if [ -n "$timestamp" ]; then
            local date_part=$(echo "$timestamp" | cut -d_ -f1)
            local time_part=$(echo "$timestamp" | cut -d_ -f2)
            local formatted_date=$(date -j -f "%Y%m%d" "$date_part" "+%Y-%m-%d" 2>/dev/null || echo "$date_part")
            local formatted_time=$(echo "$time_part" | sed 's/\(..\)\(..\)\(..\)/\1:\2:\3/')
            echo "  • $session_name (killed: $formatted_date $formatted_time)"
        else
            echo "  • $session_name"
        fi
    done
}

# Main command handler
case "${1:-}" in
    save)
        save_to_trash "$2"
        ;;
    restore)
        restore_from_trash
        ;;
    list)
        list_trash
        ;;
    clean)
        clean_trash
        echo "Trash cleaned (keeping last $MAX_TRASH_ITEMS items)"
        ;;
    *)
        echo "Usage: $0 {save <session_name>|restore|list|clean}"
        echo ""
        echo "Commands:"
        echo "  save <name>  - Save a session to trash (usually called by hook)"
        echo "  restore      - Interactive restore from trash"
        echo "  list         - List sessions in trash"
        echo "  clean        - Clean old trash items"
        exit 1
        ;;
esac