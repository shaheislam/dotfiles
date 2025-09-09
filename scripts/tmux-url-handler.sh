#!/bin/bash

# tmux URL handler script - opens URLs from tmux pane content
# Based on: https://dev.to/tomoviktor/best-way-to-open-urls-in-your-terminal-via-tmux-595b
# Usage: tmux-url-handler.sh [full]
#   - no args: capture visible pane content only
#   - full: capture full scrollback history

set -e

name="tmux-url-handler"
buffer_file_name="tmux-url-buffer-$$"
temp_file="/tmp/$buffer_file_name"


# Cleanup function
cleanup() {
    rm -f "$temp_file"
}
trap cleanup EXIT

# Capture tmux pane content
if [ "$1" = "full" ]; then
    # Capture full scrollback history
    tmux capture-pane -S - -p > "$temp_file"
else
    # Capture only visible content
    tmux capture-pane -p > "$temp_file"
fi

# Extract URLs and domain names using regex and remove duplicates
# Match both full URLs and standalone domain names
http_urls=$(grep -Eoi "(http|https)://[a-zA-Z0-9+./?=_%:-]+" "$temp_file" || true)
domain_names=$(grep -Eoi "\b[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.([a-zA-Z]{2,}\.)*[a-zA-Z]{2,}\b" "$temp_file" | grep -v "^[0-9.]*$" || true)

# Combine and deduplicate
urls=$(printf "%s\n%s\n" "$http_urls" "$domain_names" | grep -v "^$" | sort | uniq)

# Function to normalize URL (add https:// if missing)
normalize_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        echo "$url"
    else
        echo "https://$url"
    fi
}

# Check if any URLs were found
if [ -z "$urls" ]; then
    tmux display-message "#[fg=yellow]$name: No URLs found in pane"
    exit 0
fi

# Count URLs
url_count=$(echo "$urls" | wc -l)

# If only one URL, open it directly
if [ "$url_count" -eq 1 ]; then
    normalized_url=$(normalize_url "$urls")
    open -a Firefox "$normalized_url" > /dev/null 2>&1 &
    tmux display-message "#[fg=green,bold]$name: Opened $normalized_url"
    exit 0
fi

# For more than 5 URLs, use fzf in a new window
if [ "$url_count" -gt 5 ]; then
    if ! command -v fzf >/dev/null 2>&1; then
        tmux display-message "#[fg=red]$name: fzf not found, install it for better URL selection"
        exit 1
    fi
    
    tmux new-window -n "url-select" "
        selected=\$(printf '%s\n' '$urls' | fzf --prompt='Select URL: ' --height=40% --border --exit-0)
        if [ -n \"\$selected\" ]; then
            if [[ \"\$selected\" =~ ^https?:// ]]; then
                normalized_url=\"\$selected\"
            else
                normalized_url=\"https://\$selected\"
            fi
            open -a Firefox \"\$normalized_url\" > /dev/null 2>&1 &
            tmux display-message '#[fg=green,bold]$name: Opened \$normalized_url'
        else
            tmux display-message '#[fg=yellow]$name: No URL selected'
        fi
    "
else
    # For 5 or fewer URLs, use tmux display-menu with simplified commands
    menu_items=()
    index=1
    
    while IFS= read -r url; do
        # Normalize URL for opening
        if [[ "$url" =~ ^https?:// ]]; then
            normalized_url="$url"
            clean_url=${url#*://}
        else
            normalized_url="https://$url"
            clean_url="$url"
        fi
        
        # Limit display length to prevent menu overflow
        if [ ${#clean_url} -gt 50 ]; then
            clean_url="${clean_url:0:47}..."
        fi
        
        # Create a simple command that will work
        menu_items+=("$clean_url" "$index" "run-shell 'open -a Firefox \"$normalized_url\" >/dev/null 2>&1 & tmux display-message \"#[fg=green,bold]$name: Opened $normalized_url\"'")
        
        ((index++))
        if [ "$index" -gt 9 ]; then
            break
        fi
    done <<< "$urls"
    
    # Add separator and cancel option
    menu_items+=("" "" "Cancel" "q" "")
    
    tmux display-menu -t 1 -T "#[fg=cyan,bold]Select URL" "${menu_items[@]}"
fi