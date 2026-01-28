#!/bin/bash

# tmux URL handler script - opens URLs from tmux pane content
# Based on: https://dev.to/tomoviktor/best-way-to-open-urls-in-your-terminal-via-tmux-595b
# Smart capture: tries visible pane first, falls back to full scrollback if no URLs found

set -e

name="tmux-url-handler"
buffer_file_name="tmux-url-buffer-$$"
temp_file="/tmp/$buffer_file_name"


# Cleanup function
cleanup() {
    rm -f "$temp_file"
}
trap cleanup EXIT

# Function to capture URLs from pane content
# Args: $1 = capture mode ("visible" or "full")
capture_urls() {
    local capture_mode="$1"

    if [ "$capture_mode" = "full" ]; then
        tmux capture-pane -S - -p > "$temp_file"
    else
        tmux capture-pane -p > "$temp_file"
    fi

    # Extract URLs and domain names
    local http_urls=$(grep -Eoi "(http|https)://[a-zA-Z0-9+./?=_%:-]+" "$temp_file" || true)
    local domain_names=$(grep -Eoi "\b[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.([a-zA-Z]{2,}\.)*[a-zA-Z]{2,}\b" "$temp_file" | grep -v "^[0-9.]*$" || true)

    # Combine and deduplicate
    printf "%s\n%s\n" "$http_urls" "$domain_names" | grep -v "^$" | sort | uniq
}

# Smart capture: try visible pane first, fall back to full scrollback if no URLs found
urls=$(capture_urls "visible")

if [ -z "$urls" ]; then
    urls=$(capture_urls "full")
fi

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

    # Write URLs to a temp file for the new window to read
    # This avoids shell escaping issues with special characters in URLs
    url_file="/tmp/tmux-url-list-$$"
    echo "$urls" > "$url_file"

    # Use bash explicitly since tmux default-shell may be Fish (which doesn't support [[ ]])
    tmux display-popup -E -h 80% -w 80% "bash -c '
        url_file=\"$url_file\"
        selected=\$(cat \"\$url_file\" | fzf --prompt=\"Select URL: \" --height=100% --border)
        rm -f \"\$url_file\"
        if [ -n \"\$selected\" ]; then
            if [[ \"\$selected\" =~ ^https?:// ]]; then
                normalized_url=\"\$selected\"
            else
                normalized_url=\"https://\$selected\"
            fi
            open -a Firefox \"\$normalized_url\" > /dev/null 2>&1 &
            tmux display-message \"#[fg=green,bold]tmux-url-handler: Opened \$normalized_url\"
        else
            tmux display-message \"#[fg=yellow]tmux-url-handler: No URL selected\"
        fi
    '"
    exit 0
fi

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