#!/bin/bash
# Wrapper script to open URLs in Firefox from urlview

URL="$1"

# Debug logging (optional - uncomment to debug)
# echo "$(date): Opening URL: $URL" >> ~/dotfiles/logs/urlview.log

# Open URL in Firefox
/usr/bin/open -a "Firefox" "$URL"