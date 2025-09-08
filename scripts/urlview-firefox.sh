#!/bin/bash
# Wrapper script to open URLs in Firefox from urlview

URL="$1"

# Debug logging
mkdir -p ~/dotfiles/logs
echo "$(date): Original URL: $URL" >> ~/dotfiles/logs/urlview.log

# Add http:// if URL starts with www. but has no protocol
if [[ "$URL" =~ ^www\. ]]; then
    URL="http://$URL"
    echo "$(date): Modified URL: $URL" >> ~/dotfiles/logs/urlview.log
fi

# Open URL in Firefox
/usr/bin/open -a "Firefox" "$URL"

# Log exit status
echo "$(date): Exit status: $?" >> ~/dotfiles/logs/urlview.log