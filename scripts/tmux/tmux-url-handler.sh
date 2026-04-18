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
        tmux capture-pane -J -S - -p >"$temp_file"
    else
        tmux capture-pane -J -p >"$temp_file"
    fi

    # Extract scheme-qualified URLs and bare domains with common TLDs
    # Bare domains (e.g. google.com, bbc.co.uk) are normalized to https:// when opened
    grep -Eoi "(https?://[a-zA-Z0-9./?=_:%+#&~@!*(),;_%-]+|[a-zA-Z0-9][a-zA-Z0-9.-]*\.(com|org|net|io|dev|co\.uk|gov\.uk|edu|info|me|app)\b[/a-zA-Z0-9./?=_:%+#&~@!*(),;_%-]*)" "$temp_file" | sort | uniq || true
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
    open -a Firefox "$normalized_url" >/dev/null 2>&1 &
    tmux display-message "#[fg=green,bold]$name: Opened $normalized_url"
    exit 0
fi

# Always use tmux display-menu with simplified commands
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

    # Create a simple command that will work
    menu_items+=("$clean_url" "$index" "run-shell 'open -a Firefox \"$normalized_url\" >/dev/null 2>&1 & tmux display-message \"#[fg=green,bold]$name: Opened $normalized_url\"'")

    ((index++))
    if [ "$index" -gt 9 ]; then
        break
    fi
done <<<"$urls"

# Add separator and cancel option
menu_items+=("" "" "Cancel" "q" "")

tmux display-menu -t 1 -T "#[fg=cyan,bold]Select URL" "${menu_items[@]}"
